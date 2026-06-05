# Art Bible — Garrison

> **Status**: Complete — All 9 Sections
> **Author**: art-director
> **Last Updated**: 2026-05-19
> **Stage**: Pre-Production
> **AD Sign-Off (AD-ART-BIBLE)**: Lean mode — auto-approved
> **Sections Complete**: 1, 2, 3, 4, 5, 6, 7, 8, 9

---

## Section 1: Visual Identity Statement

> **One-Line Visual Rule**:
> *Every visual element in Garrison must be identifiable, legible, and purposeful at a glance on a 540×960 screen held one-handed.*

This rule governs every asset decision in the game. When in doubt, choose the
option that makes the scene MORE readable, never less. Decorative complexity
is never worth sacrificing the split-second legibility that mobile one-thumb play demands.

### Supporting Principles

**Principle 1: Warmth belongs to the player; cold belongs to the threat.**
All player-controlled entities (hero, archers, archer towers) use warm tones
(gold, royal blue, amber). All enemies use cold or saturated-danger tones
(dark red, violet, maroon). The map background is neutral (greens, sand).
When a visual choice is ambiguous — "what color should this VFX flash be?" —
this principle says: if it came from the player, warm. If from the enemy, cold.

*Pillar served*: Pillar 4 — "Tension sans panique." The enemy-as-cold-threat
language communicates danger without inducing panic; the warm hero presence
signals safety and agency even when surrounded.

**Principle 2: The army's growth must be instantly countable.**
The formation of archers around the hero is the game's primary power display.
At any moment, the player must be able to count their archers at a glance — even
in motion, even mid-combat. This demands clear silhouette separation between
individual archer sprites and a consistent position rhythm in the V-formation.
When in doubt, increase the spacing before the density.

*Pillar served*: Pillar 3 — "L'armée se voit grandir." Power is visible and
spatial, not hidden in stats. If the upgrade isn't visible on screen, it isn't
communicating the fantasy.

**Principle 3: Zones are the UI.**
In Garrison, there are no mid-combat menus. The world-space interaction zones
(RECRUIT_ZONE, TOWER_ZONE, FORGE_ZONEs) ARE the interface. They must be
immediately recognizable as interactive, visually distinct from the combat
environment, and communicative of their current state (available / dwell-active /
unavailable / locked) without text labels as primary communicators.

*Pillar served*: Pillar 1 — "Un seul doigt, zéro friction." Zones replace
buttons. They must do the work that a button's visual affordance normally does —
communicate "I am pressable" through world presence, not UI layer overlays.

---

## Section 2: Mood & Atmosphere

Garrison is played in short bursts (5–20 min) on a phone in portrait orientation.
The mood must land within 2 seconds of a session starting and sustain through
escalating pressure without tipping into chaotic noise.

### Per-State Mood Targets

**PLAYING — Early Waves (Waves 1–4: "The Calm Before")**

- **Primary emotion**: Confident anticipation. The player is building something.
  The army is small but growing. The castle stands. The threat is visible but
  manageable.
- **Lighting character**: Bright, high-key, warm-toned ambient. Midday sun direction.
  Long shadows from sprites give depth without darkness.
- **Atmospheric descriptors**: Clear, spacious, purposeful, constructive, bright.
- **Energy level**: Measured. The player has time to think. Wave pressure is real
  but not overwhelming.
- **Visual tell**: Background is full-saturated green/sand. Castle HP bar is green.
  Formation is visible and sparse (2–3 archers). Enemies are small and few.

**PLAYING — Mid Waves (Waves 5–9: "The Escalation")**

- **Primary emotion**: Focused tension. Decisions cost more. Gold is never quite
  enough. The castle has taken some hits.
- **Lighting character**: Unchanged from early — the light does not change with
  danger; the world state changes. The communication of danger is in the number
  of enemies and the HP bar, not in the lighting.
- **Atmospheric descriptors**: Busy, decisive, urgent, high-stakes, controlled.
- **Energy level**: Elevated. The inter-wave window feels shorter. The next
  volley from the formation feels more consequential.
- **Visual tell**: Enemy density is visibly higher. Castle HP bar transitions
  to amber at 50%. Formation is larger (4–6 archers). Gold coins are scattered
  across more of the map.

**PLAYING — Late Waves (Waves 10+: "The Last Stand")**

- **Primary emotion**: Strained resolve. The player knows the castle may fall.
  They are fighting for every second.
- **Lighting character**: Still the same world-space lighting — do NOT shift
  to "dark and foreboding." The game's identity is tension WITHOUT panic.
  The danger communicates through UI (castle HP bar = red), not through
  atmospheric lighting changes.
- **Atmospheric descriptors**: Packed, relentless, decisive, almost-controlled.
- **Energy level**: High but not chaotic. Volleys are constant. Gold drops are
  everywhere. The FORGE_ZONEs (Alpha) are the last lever.
- **Visual tell**: Castle HP bar is red. Archer badge is at max (8). Formation
  volleys fire at near-maximum rate. Enemy sprites nearly fill the bottom third
  of the world.

**GAME_OVER ("The Fall")**

- **Primary emotion**: Earned defeat. Not frustration — satisfaction at how far
  the player got. The wave count is the score. The player wants to see it clearly.
- **Lighting character**: Immediate transition. The game world dims slightly
  (not black — just desaturates 20–30%). The GAME_OVER score panel appears
  center-screen, lit clearly.
- **Atmospheric descriptors**: Final, clear, reflective, ready to restart.
- **Energy level**: Drops immediately to zero. Total stillness after the battle.
- **Visual tell**: Formation disperses or freezes. Castle sprite cracks or
  collapses (if animated). Score panel shows wave count prominently.

**WAVE_CLEAR ("The Breath")**

- **Primary emotion**: Brief relief + tactical urgency. The wave is over but
  the next is coming. The inter-wave window is a gift and a race.
- **Lighting character**: Brief flash of warmth — a single-frame golden light
  pulse at wave clear, then back to steady. Not a sustained lighting state.
- **Atmospheric descriptors**: Relieved, urgent, spatial, alive.
- **Energy level**: Drops from combat to sprint. Player is running to a zone.
  It is quieter but not quiet.
- **Visual tell**: Enemies are gone or dying. Gold is scattered. Zone indicators
  pulse. Wave countdown begins.

---

## Section 3: Shape Language

The game is 2D top-down on mobile. Sprites are viewed from above at a fixed
camera distance. Shapes must be readable at small pixel sizes (hero radius = 18px
in world space, occupies ~16×16 pixels in viewport).

### Character Silhouette Philosophy

**Hero**:
- Silhouette rule: must be unmistakably distinct from every other entity at
  thumbnail size (16×16px or smaller).
- Shape: compact, upright, slightly taller than wide. A centered bright element
  (crown, glowing badge) identifies it from any angle.
- Rule: if you can confuse the hero with an archer, the hero sprite needs work.

**Archers**:
- Silhouette rule: smaller than the hero, similar cultural aesthetic but
  distinctly subordinate. Readable as a group, not as individuals.
- Shape: rounder, shorter, uniform. The V-formation reads as a flock, not
  as individual units. Individual archer distinctness is less important than
  formation cohesion as a group visual.
- Rule: at 8 archers in the V-formation, the formation must still read as
  "a unified group of 8" and not as "visual noise."

**Enemies**:
- Silhouette rule: angular, directional. Enemies have a visible "facing" implied
  by their shape — they are moving TOWARD the castle. The sprite should lean
  into that direction.
- Shape: slightly elongated toward their movement direction. Distinctly non-circular
  (hero and archers are round; enemies are angular — never confuse the two).
- Rule: at 20 enemies on screen, the mass must read as "a wave of threats" not
  as "a scattered crowd."

**Zones (RECRUIT_ZONE, TOWER_ZONE, FORGE_ZONEs)**:
- Silhouette rule: zones are the largest interactive "objects" in the world space
  (90px radius circles). They must not compete with entities for visual hierarchy.
- Shape: flat, circular, ground-plane element. Below entities, never above.
  The zone occupies the ground, not the air. Entity sprites are drawn over zones.
- Rule: zones communicate state through fill color and pulse animation, not through
  competing with character sprites for visual space.

### Environment Geometry

- **Dominant style**: Flat, top-down, orthographic. No perspective distortion on
  tiles. The world is a flat field.
- **Tile geometry**: Simple, low-detail. Grass tiles, sand/dirt tiles, stone for
  castle area. Tiles must not draw the eye — they are background.
- **Castle**: The one structure in MVP. Architecturally simple — a keep silhouette
  readable from directly above. Visible HP state through sprite change or overlay
  (green → cracked → heavily damaged).
- **Anti-rule**: Do NOT add decorative world detail (trees, boulders, fences) until
  after core gameplay is validated at Alpha. Every decorative element must clear
  the legibility rule before it is added.

### UI Shape Grammar

- UI elements (HUD strip) use a distinct visual language from the world: flat,
  high-contrast, screen-space. They sit above the world on CanvasLayer.
- Icon shapes: geometric and minimal. Gold icon = stylized coin (circle with inner
  ring). Archer badge = arrow silhouette. Castle = keep outline.
- All interactive zone indicators (dwell progress bar) use circular fill — matching
  the zone's circular world-space shape. This creates visual continuity between
  the zone in the world and the feedback in the HUD.
- Shape rule: UI icons are never illustrations — they are symbols. Symbols must
  communicate at 16×16px.

---

## Section 4: Color System

### Primary Palette

| Role | Color Name | Approximate Hex | Meaning |
|------|-----------|-----------------|---------|
| **Hero / Ally Primary** | Royal Gold | `#F5C518` | Player agency, reward, warmth |
| **Hero / Ally Accent** | Royal Blue | `#2A5FC9` | Authority, command, allied unit identity |
| **Enemy Primary** | Threat Red | `#C0392B` | Danger, hostile, blood |
| **Enemy Accent** | Dark Violet | `#5E2E6B` | Menace, mass, dark force |
| **Map Base A** | Grass Green | `#4A7C59` | Neutral terrain, safe ground |
| **Map Base B** | Sand Beige | `#D4B896` | Neutral terrain variant, castle courtyard |
| **Castle Stone** | Grey Stone | `#9B9B9B` | Structure, permanence, defensible |
| **Economy / Collectible** | Bright Gold | `#FFD700` | Collectible, reward, spend signal |
| **Zone Available** | Pulse Green | `#27AE60` | "I am interactive, approach me" |
| **Zone Locked** | Muted Grey | `#7F8C8D` | "Not yet available" |

### Semantic Color Vocabulary

This is the color language of Garrison. Every color decision must be consistent
with these meanings:

- **Gold / Yellow** (`#FFD700`, `#F5C518`): player currency, allied entities,
  rewards, warmth. Never used for enemies or danger.
- **Red** (`#C0392B`): enemy entities, castle under threat (HP bar critical state),
  danger communication. Never used for allied entities.
- **Green** (`#27AE60`, `#4A7C59`): available/interactive (zone pulse), healthy
  castle (HP bar full state), safe terrain. When green appears on a zone, it
  means "you can spend here."
- **Blue** (`#2A5FC9`): hero identity accent, allied unit secondary. Cool-but-allied
  — distinguishes the hero from both warm gold (passive) and cold red (enemy).
- **Grey** (`#7F8C8D`, `#9B9B9B`): locked/unavailable zones, castle structure,
  neutral information. Grey means "not yet in play."
- **Violet / Dark Purple** (`#5E2E6B`): enemy mass, elite/boss variant. Amplifies
  the threat tone of red without the urgency — used for larger enemy types.

### Castle HP Bar Color States

The castle HP bar is the primary danger indicator. It uses a three-state color
transition (never just one color throughout):

| HP Range | Bar Color | Additional Signal |
|----------|-----------|-------------------|
| 100–51% | Pulse Green `#27AE60` | Numeric HP displayed |
| 50–26% | Amber `#E67E22` | Numeric HP displayed + slow pulse |
| 25–0% | Threat Red `#C0392B` | Numeric HP displayed + fast pulse (≤1Hz) |

**CRITICAL — Color independence**: The HP bar MUST always display a numeric value
alongside the color fill. Color is a secondary signal, not the primary one.
Reference: `design/accessibility-requirements.md` Section 2.2.

### Zone State Colors

| Zone State | Visual Color | Animation |
|-----------|-------------|-----------|
| ZONE_AVAILABLE | Pulse Green `#27AE60` | Slow radial pulse (1 beat/1.5s) |
| ZONE_DWELL_ACTIVE | Bright Green `#2ECC71` | Fill arc sweeps clockwise at dwell rate |
| ZONE_UNAVAILABLE (afford check fail) | Muted Grey `#7F8C8D` | No animation; static |
| ZONE_INACTIVE (MVP — Forge locked) | Hidden | Not rendered |

### Colorblind Safety

The game uses red vs. green as primary semantic contrast (enemy vs. zone available).
This is a known risk for Deuteranopia (red-green colorblind, ~8% of males).

**Required non-color backups**:

| Semantic Pair | Color Risk | Backup |
|---|---|---|
| Enemy (red) vs. Zone (green) | Deuteranopia | Enemy silhouette is angular/directional; Zone is circular/ground-plane |
| HP bar (green→red gradient) | Deuteranopia | Numeric HP always displayed; pulse animation rate changes |
| Zone available (green) vs. locked (grey) | Tritanopia (low risk) | Zone has pulse animation when available; no animation when locked |

### Per-Area Color Temperature

MVP has a single map area. Color temperature is uniform. Post-MVP area expansion
should follow this rule: each new area shifts the map base hue by no more than
±15° on the color wheel from the MVP baseline (`#4A7C59` grass green) to maintain
visual continuity. Enemy and ally palettes remain constant across all areas —
they are identity colors, not environmental colors.

### UI Palette

The HUD strip sits on a semi-transparent dark background (`rgba(0,0,0,0.55)`).
All HUD text and icons are rendered in white or the semantic color appropriate
to the element:

- Gold counter: `#FFD700` icon + white numeric text
- Archer badge: `#F5C518` arrow icon + white numeric text
- Castle HP bar: semantic color (see HP state table above) + white numeric text
- Wave label: white text on dark strip

**Contrast compliance** (WCAG 2.1 AA): White text on `rgba(0,0,0,0.55)` over
any game world color achieves > 4.5:1 contrast ratio — verified by calculation
at worst case (over `#4A7C59` grass green).

---

---

## Section 5: Character Design Direction

### Overview

All characters in Garrison are 2D top-down sprites viewed from directly above at a
fixed camera distance. Each sprite must read unmistakably at its working pixel size
in viewport space. Viewport is 540×960; world-to-viewport ratio is 1:1 in MVP
(no camera zoom).

### Sprite Size Reference

| Entity | World radius | Approx viewport size | Min readable detail |
|--------|-------------|---------------------|---------------------|
| Hero | 18px | ~36×36 viewport pixels | Silhouette + facing indicator |
| Archer | 12px | ~24×24 viewport pixels | Silhouette only |
| Enemy (base) | 14px | ~28×28 viewport pixels | Silhouette + directional lean |
| Enemy (elite) | 20px | ~40×40 viewport pixels | Distinct outline shape |
| Castle | 50px | ~100×100 viewport pixels | HP state visible |

---

### 5.1 Hero — "The King"

**Role**: The player's avatar. Must be unmistakable at all times.

**Visual character**:
- Compact upright silhouette, slightly taller than wide
- Primary color: Royal Gold `#F5C518` body fill with Royal Blue `#2A5FC9` accent trim
- Facing indicator: directional "arrow" or cape-flick indicating movement direction (aligned with `facing_angle`)
- Distinctive landmark: a small crown or glowing badge at the "head" of the sprite — present even when sprite is tiny
- Outline: thick 2px black outline at world scale — ensures readability over any terrain tile

**Top-down art direction**:
- View: directly from above. The sprite is a circular silhouette with a directional cue (the facing arrow or cloak)
- Scale: occupies ~36px in viewport; the crown/badge should be ~8px minimum
- At-a-glance rule: if you see gold+blue+crown in any combination, you have found the hero

**States**:
- `IDLE` / `MOVING`: same sprite, facing arrow rotates with `facing_angle`. No walk cycle needed in MVP (prototype-quality acceptable).
- `GAME_OVER`: hero sprite frozen in last position, 30% dimmed (no special "defeated" sprite needed in MVP)

**Placeholder (MVP)**: Filled circle `#F5C518` with smaller `#2A5FC9` directional arrow inside. No art required to implement.

---

### 5.2 Archers — "The Formation"

**Role**: Power display. They must be countable as a group at all times.

**Visual character**:
- Rounder, shorter than the hero. Subordinate — similar warm aesthetic but clearly different.
- Primary color: Warm Cream `#E8D5A3` or Amber `#C8962A` — similar family to hero gold but duller (less important individually)
- Accent: Brown/wood `#8B6914` (bow, quiver) — earthy, natural
- Outline: 1.5px black — slightly thinner than hero to reinforce hierarchy
- No facing indicator needed: archers rotate with the formation; their orientation in the V communicates direction

**Group legibility rule**:
At 8 archers in V-formation (max), the formation must read as a unified group, not as visual noise.
Test: screenshot the game at max formation density and count archers. If you cannot count to 8 in under 3 seconds, increase inter-archer spacing in the V offsets.

**Individual legibility rule**:
Archers do not need to be individually distinguishable from each other. They are a flock, not individuals.

**States**:
- Default: small filled circle with bow-shape overlay. No walk cycle.
- `formation_full` (8/8): brief 0.3s scale pulse (+15%) on the whole formation when the badge hits "8/8". Single event, not sustained.

**Placeholder (MVP)**: Small filled circle `#C8962A` — 24px diameter in viewport. No art required.

---

### 5.3 Enemies — Base Type

**Role**: Threat wave. Must communicate "moving toward the castle" at any density.

**Visual character**:
- Angular, directional silhouette — elongated toward their movement direction
- Primary color: Threat Red `#C0392B` body, Dark Violet `#5E2E6B` outline
- Movement cue: sprite has a visible "nose" or "point" facing toward the castle — the shape itself communicates direction without requiring animation
- Outline: 1.5px Dark Violet — differentiates from hero/archers which have black outlines
- HP bar: thin red bar above sprite (world space), shrinks as HP is depleted. 20px wide × 4px tall.

**At-a-glance rule**: If you can see red+angular+directional, you have found an enemy.
**Mass rule**: At 20 enemies on screen, the mass should look like a "red wave rolling toward the castle" — a coherent threat, not a scattered crowd. Uniform sprite size and color achieve this.

**States**:
- `ALIVE`: standard sprite, directional toward castle
- `TAKING_DAMAGE`: single-frame white flash on hit (1 frame at 60fps = 16ms) — fast enough to feel impactful, not long enough to be distracting
- `DEAD` / cleanup: sprite removed from draw list immediately. No death animation in MVP (acceptable). Post-MVP: 0.3s scale-down before removal.

**Enemy HP bar**:
- Position: 6px above sprite top, centered on sprite x
- Size: proportional to enemy max HP width. Shrinks left-to-right as HP decreases.
- Color: Threat Red `#C0392B`. No color band — enemies use a single color HP bar (distinguish from castle bar)

**Placeholder (MVP)**: Angular triangle or teardrop shape `#C0392B` with dark violet outline. Pointing toward castle.

---

### 5.4 Enemies — Elite Variant (Wave 5+)

**Role**: Escalation signal. Players see something different and know "harder wave."

**Visual character**:
- Same color family as base enemy (Threat Red + Dark Violet) but visually larger and bulkier
- Added accent: Dark Violet `#5E2E6B` inner fill, red outer shape — inverted from base enemy
- 1.5× base enemy scale. More angular. Outline is thicker (2px).
- HP bar proportionally wider and starts at a higher value

**Placeholder (MVP)**: Larger `#5E2E6B` filled triangle with `#C0392B` outline. 1.5× base size.

---

### 5.5 Visual Hierarchy Summary

At any frame of gameplay, visual hierarchy from most to least important:

1. **Hero** — largest, most colorful, unique gold+blue
2. **Castle** — largest static element, stone texture
3. **Enemy mass** — red angular wave
4. **Formation archers** — smaller warm group
5. **Gold coins** — small bright yellow collectibles (see Economy rules)
6. **Zones** — ground-plane circles (never above entities)
7. **Terrain tiles** — background, never compete for attention

---

## Section 6: Environment Design Language

### 6.1 Map Philosophy

MVP has exactly one map area. The map must:
- Never draw the player's eye away from entities and zones
- Provide clear spatial context ("this is a field in front of a castle")
- Support the color contrast requirements (warm allies / cold enemies / neutral terrain)

**Dominant aesthetic**: Flat, clean, top-down. No pseudo-3D depth tricks. No
perspective distortion. Tiles are uniform ground texture with minimal variation.

---

### 6.2 Terrain Tiles

**Ground base**: Grass Green `#4A7C59` with subtle noise variation (±5% brightness per tile). No tile pattern should draw the eye more than once.

**Castle approach area** (upper portion of map): Sand Beige `#D4B896` — a stone/dirt courtyard around the castle. Approximately top 25% of the world space. This provides a visual "landing zone" that contrasts the green field and reinforces the castle as a distinct landmark.

**Border / edge**: No visible border in MVP. The map has an implied boundary based on where enemies spawn (offscreen edges). No fencing, walls, or hard edges needed.

**Tile size**: 32×32 world-pixels. The 2160×2160 world (4× viewport) uses 68×68 tile grid. Do not render tiles outside the camera view (use Godot's built-in culling or TileMap).

**MVP acceptability**: Flat colored rectangle for grass + flat beige rectangle for courtyard. No tile art needed to ship MVP. The focus is legibility, not art.

---

### 6.3 Castle

**Role**: The objective. The thing being defended. Its HP state must be visually readable at all times.

**Top-down silhouette**:
- A compact keep shape — roughly square with small corner towers suggested
- Color: Grey Stone `#9B9B9B` body, darker outline `#666666`
- Scale: ~100px diameter in viewport (50px world radius)
- Facing: the castle "entrance" faces downward (toward the enemy spawn area)

**HP states** (communicated through sprite or overlay):
- `HEALTHY (HP > 60%)`: full stone color, no special indicator
- `DAMAGED (30–60%)`: stone shows crack lines (sprite swap or overlay)
- `CRITICAL (< 30%)`: castle sprite shifts to desaturated/red-tinted. Slow pulse (1Hz, under flicker threshold)
- `GAME_OVER (HP = 0)`: castle collapses or darkens. Frozen at time of fall.

**MVP acceptability**: Single colored circle `#9B9B9B` with black outline. HP color bands using sprite modulate (no separate art assets needed). Can add crack sprite overlay in Alpha.

---

### 6.4 Interaction Zones

Zones are world-space circles on the ground plane. They must never visually compete with entity sprites. Zones are drawn BELOW entities in the render order.

**RECRUIT_ZONE**:
- Position: `(135, 490)` world space
- Radius: 55px (world) = 55px viewport at 1:1 scale
- Available state: Pulse Green `#27AE60` fill at 30% opacity, slow pulse ring (outer ring at 100% opacity, 1 beat/1.5s)
- Dwell-active state: Arc fill sweeps clockwise from top (0°), filling to completion at 0.8s. Fill color `#2ECC71`. Clear visual progress indicator.
- Unavailable (cannot afford): Muted Grey `#7F8C8D` at 20% opacity. No pulse. Static.
- Label: Optional small text "RECRUIT" below zone center in white 10px — only visible when zone is available (not rendered when unavailable). Note: zones ARE the UI (Principle 3) — the label is supplementary.

**TOWER_ZONE** (MVP scope, per design decision D-01):
- Same visual grammar as RECRUIT_ZONE but different position
- Accent color: Royal Blue `#2A5FC9` instead of green (tower = permanent structure vs. troop recruit)
- Label: "TOWER" optional

**FORGE_ZONEs** (Alpha scope — 4 zones):
- Position: 4 zones around the castle area (Alpha — not in MVP build)
- Visual language: same ground-circle pattern but smaller (40px radius)
- Distinct icon per upgrade type (damage/speed/range/HP) — to be defined in Alpha art spec

---

### 6.5 Gold Coins

**Role**: Economy collectible. Must be immediately visible against any terrain.

- Shape: small circle `#FFD700` (Bright Gold) with thin black outline
- Size: 8px radius (world) = 8px viewport
- Animation: gentle bob up/down ±3px over 0.5s cycle (2Hz — below flicker threshold, creates life)
- Magnet range (visual): no visual indicator for the magnet radius — the coins just fly toward the hero when in range. The "pull" animation communicates the mechanic.
- Collection animation: coins fly toward hero position over 0.15s, then disappear.

**MVP acceptability**: Static small yellow circle. No animation required in MVP.

---

## Section 7: UI/HUD Visual Direction

### 7.1 HUD Strip Visual

The HUD is a `CanvasLayer` overlaid on the game world. It uses a distinct visual language from the world — flat, high-contrast, screen-space.

**Strip background**: `Color(0.0, 0.0, 0.0, 0.55)` — semi-transparent dark. 540px wide × 48px tall (plus safe-area offset). The strip must be dark enough to achieve >4.5:1 contrast with white text, light enough to remain transparent enough to see the game world edge.

**Element rendering order** (back to front): strip background → castle HP bar track → bar fill → bar numeric → gold icon → gold numeric → wave label → archer icon → archer numeric.

**Full spec**: See `design/ux/hud.md` for element positions, sizes, colors, and update behaviors.

---

### 7.2 HUD Icon Specifications

**Gold icon** (coin):
- Style: flat geometric. Outer circle `#FFD700`, inner ring `#C8A800`. 14×14px rendered.
- Meaning: currency, collectible, spend-signal

**Archer badge icon** (bow/arrow):
- Style: simple arrow silhouette, pointing right. `#C8962A`. 14×14px rendered.
- Meaning: formation count, army size indicator

All icons are symbols, not illustrations. They must communicate at 14×14px.

---

### 7.3 Dwell Zone Progress Arc

The dwell arc is the primary HUD feedback element that lives in WORLD SPACE (not CanvasLayer). It overlays the RECRUIT_ZONE or TOWER_ZONE when the hero is inside.

**Visual specification**:
- Type: arc drawn clockwise from 12 o'clock (top of circle)
- Radius: zone radius (55px)
- Line weight: 4px bright `#2ECC71`
- Background track: 2px dull `#1A7A40` full circle (shows how far to go)
- Fill progress: 0.0 (hero just entered) → 1.0 (0.8s dwell complete) → full arc
- On completion: brief 3-frame white flash of the full circle, then zone activates
- On exit (before complete): arc disappears immediately — no partial carry (GDD R7)

---

### 7.4 GAME_OVER Overlay Visual

**Full spec**: See `design/ux/game-over.md`.

**Visual direction summary**:
- Dark overlay: `Color(0.05, 0.05, 0.08, 0.70)` — deep dark blue-tint
- Panel: `Color(0.1, 0.08, 0.12, 0.92)` — near-opaque dark violet (aligns with `#5E2E6B` family)
- Panel corners: 12px radius rounded rect
- Headline "CASTLE FELL": white, bold, 24px, center-aligned
- Stats: white, regular, 16px
- CTA "TAP ANYWHERE TO RESTART": white, regular, 14px, pulsing opacity

---

### 7.5 Visual Anti-Rules (UI Layer)

- **No gradient backgrounds on UI panels** — flat colors only. Gradients introduce visual noise at small sizes on mobile screens.
- **No drop shadows on game world elements** — sprites use outline-only shadows where needed. CanvasLayer elements may have subtle shadow but only for text legibility.
- **No rounded corners on HUD strip** — the strip is a full-width band. Corners are an irrelevant design element.
- **No decorative border on the HUD strip** — the strip background provides the boundary. A border adds visual noise without communicating information.

---

## Section 8: Asset Standards

### 8.1 File Organization

```
assets/
  characters/
    hero/
      hero.png          # Main sprite
      hero.tres         # SpriteFrames resource (if animated)
    archers/
      archer.png        # Single archer sprite (all archers use same sprite)
    enemies/
      enemy_base.png
      enemy_elite.png
  environment/
    castle/
      castle_healthy.png
      castle_damaged.png   # Optional, Alpha milestone
      castle_critical.png  # Optional, Alpha milestone
    terrain/
      tile_grass.png    # 32×32
      tile_sand.png     # 32×32
  ui/
    icons/
      icon_gold.png     # 14×14 coin
      icon_archer.png   # 14×14 bow/arrow
    hud/              # HUD elements (if using TextureRect nodes)
  vfx/
    impact_flash.png  # 1-frame hit flash sprite
    coin_collect.png  # Coin collection VFX (optional Alpha)
```

---

### 8.2 Sprite Format Standards

| Property | Requirement |
|----------|-------------|
| Format | PNG with transparency (RGBA) |
| Color space | sRGB |
| Max size | Characters: 64×64px. Environment tiles: 32×32px. UI icons: 16×16px or 14×14px. |
| Export DPI | 72 DPI (screen only, no print) |
| Pixel art | YES — no anti-aliasing on sprite edges. Import with `Filter: Nearest`. |
| Compression | Lossless PNG (Godot import: `detect: true`, `compress/mode: 0`) |
| Naming | `[category]_[name]_[state].png` — all lowercase, underscores, no spaces |

---

### 8.3 Godot Import Settings

For all game sprites:
```
[params]
compress/mode=0        # Lossless
compress/lossy_quality=0.7
detect_3d/compress_to=1
filter=false           # Pixel art: no bilinear filter
generate_mipmaps=false # Mobile 2D: no mipmaps needed
repeat=0               # No tile repeat on sprites
fix_alpha_border=true
premult_alpha=false
```

For terrain tiles (TileMap):
```
filter=false           # Pixel art
repeat=0
generate_mipmaps=false
```

---

### 8.4 Placeholder vs. Production Assets

| Milestone | Asset Quality | Standard |
|-----------|--------------|----------|
| MVP | Placeholder geometric shapes (colored circles/polygons) | No art files needed — drawn via GDScript `_draw()` |
| Vertical Slice | Placeholder + color coding | Simple colored sprites, no animation required |
| Alpha | Production sprites (no animation) | Pixel art sprites per spec above, no walk cycles |
| Full Vision | Production animated sprites | Walk cycles, hit reactions, death animations |

**MVP acceptability rule**: Any system that can be expressed as a colored geometric shape
using GDScript's `_draw()` does NOT require art assets in MVP. Replace progressively as
the milestone milestone plan advances.

---

### 8.5 Naming Conventions

| Asset type | Convention | Example |
|---|---|---|
| Character sprites | `[entity]_[state].png` | `hero_default.png`, `enemy_base_hit.png` |
| Terrain tiles | `tile_[type].png` | `tile_grass.png`, `tile_sand.png` |
| UI icons | `icon_[name].png` | `icon_gold.png`, `icon_archer.png` |
| VFX | `vfx_[event].png` | `vfx_hit_flash.png` |

---

## Section 9: Reference Direction

### 9.1 Primary Style Reference

**Archero** (Habby, 2019) — Top-down mobile action. Clean geometric sprites, strong
silhouette contrast between player and enemies. Warm/cool color contrast. Excellent
mobile readability at small sizes. Note: Archero uses isometric-adjacent perspective
and more detailed sprites; Garrison uses flat top-down and simpler shapes.

**Vampire Survivors** (Poncle, 2022) — Sprite style is rough but highly legible.
Enemy masses read as threat. The gold coin visual language is nearly identical to
what Garrison targets. Strong precedent for "geometric placeholder that communicates
clearly at 16px."

**Minit** (JW Nijman et al, 2018) — Extreme constraint in visual language. Black and
white 8px sprites that communicate perfectly at tiny sizes. Reference for: "how simple
can the sprite be before it stops communicating?"

### 9.2 What We Take From Each Reference

| Reference | What We Take |
|---|---|
| Archero | Character scale on mobile, warm/cool contrast, icon-based HUD approach |
| Vampire Survivors | Gold coin visual language, mass enemy communication, "game world over HUD" priority |
| Minit | Minimum viable sprite complexity — simple shapes + outlines > illustration |
| Clash of Clans | Castle visual language, color-coded zone states, HP bar behavior |

### 9.3 What We Explicitly Reject

- **Archero**: perspective warping, hero-death-as-loss-mechanic, complex particle VFX
- **Vampire Survivors**: horizontal orientation, complex ability tree UI, detailed creature illustrations
- **Any reference using off-white or dark backgrounds**: Garrison's terrain is mid-green and beige — never dark. This is a daylit field, not a dungeon.

### 9.4 Target Fidelity at Each Milestone

| Milestone | Visual Fidelity Target |
|-----------|----------------------|
| MVP | Colored circles and polygons — 100% placeholder. Not shown to players. |
| Vertical Slice | Placeholder shapes + color coding. Sufficient for first-impression playtests. |
| Alpha | Simple pixel-art sprites with correct silhouettes and color palette. No animations. Internal playtests ready. |
| Full Vision | Animated pixel-art sprites, tile-based terrain, polished VFX. External playtest ready. |

### 9.5 Art Production Order

When production begins, create assets in this priority order:

1. **Hero sprite** (first — all playtests star this entity)
2. **Enemy base sprite** (second — threat must be visually clear)
3. **Archer sprite** (third — formation must be readable)
4. **Castle sprite** (fourth — the objective must be visually distinct)
5. **Ground tiles** (fifth — only after all entities are readable over placeholder terrain)
6. **Gold coin** (sixth — economy feedback asset)
7. **Dwell arc VFX** (seventh — zone interaction feedback)
8. **HUD icons** (eighth — gold icon, archer badge icon)
9. **Enemy elite sprite** (ninth — differentiation for wave escalation)
10. **VFX / polish** (last — only after full gameplay is readable at Alpha)

---

## Art Bible Sign-Off

**AD-ART-BIBLE**: Lean mode — sections 5–9 authored autonomously. Full review deferred to `/gate-check pre-production`.

---

*Art bible completed: 2026-05-19 — All 9 sections authored.*
*Pre-Production gate requires all 9 sections + AD sign-off (lean: auto-approved).*
