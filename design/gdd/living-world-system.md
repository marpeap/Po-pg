# Living World System — Garrison RPG
## Status: Designed
## Version: 1.0 — 2026-05-25
## Author: Systems Design (Living World)

---

## Overview

This document specifies the complete living world system for the Garrison RPG exploration
layer (EXPLORING state). The world spans 48000×2160 world units across 15 zones and must
feel alive on a 960×540 landscape viewport at 60fps with at most 150 draw calls. All 7
subsystems (Day/Night, Weather, Seasons, World State, Ambient Life, Ambient Audio, World
Memory) are designed to interlock — weather changes audio, seasons tint zones and unlock
events, world state changes where NPCs roam. Every system is session-scoped unless
explicitly marked as ConfigFile-persistent.

---

## 1. Day/Night Cycle

### 1.1 Design Reference

Stardew Valley: one in-game day = ~14 real minutes, clear player pressure (pass out at 2am).
BOTW: day/night visible through enemy type swap and temperature. Garrison targets no hard
time pressure but strong atmospheric feedback and real gameplay stakes (nocturnal enemies,
exclusive resources).

### 1.2 Parameters

| Constant | Value | Rationale |
|---|---|---|
| DAY_DURATION_SECONDS | 480.0 | 8 real minutes per full day |
| DAWN_START | 0.00 | normalized [0.0, 1.0] within day |
| DAWN_END | 0.08 | 38s — golden first light |
| DAY_START | 0.12 | 58s — full daylight |
| DUSK_START | 0.70 | 5m36s — orange light begins |
| DUSK_END | 0.80 | 6m24s — deep blue transition |
| NIGHT_START | 0.85 | 6m48s — full dark |
| NIGHT_END | 1.00 | end of cycle |

### 1.3 Ambient Color Overlay

A single full-screen ColorRect on CanvasLayer (layer=10, always on top) modulates the
entire scene via blend_mode MULTIPLY. This costs exactly 1 draw call.

```
PHASE_COLORS: Dictionary = {
    "night":  Color(0.12, 0.14, 0.28, 0.72),   # deep blue-indigo
    "dawn":   Color(0.92, 0.52, 0.22, 0.30),   # warm amber
    "day":    Color(1.00, 1.00, 1.00, 0.00),   # fully transparent — no tint
    "dusk":   Color(0.88, 0.40, 0.18, 0.38),   # orange-red
}
```

The overlay alpha is lerped smoothly between phases:
```
weight = 1.0 - pow(1.0 - 0.04, delta * 60.0)   # ADR-004 pattern — tau ~0.5s
_overlay.color = _overlay.color.lerp(target_color, weight)
```

### 1.4 Enemy Behavior by Time

| Phase | Enemy Spawn Weight Modifier | Special Types Unlocked |
|---|---|---|
| DAY | ×1.0 base weights | None |
| DUSK | ×1.15 — camps more restless | None |
| NIGHT | ×1.50 on all types; NOCTURNAL type unlocked | Nocturnal Stalker (cave-dwelling, fast) |
| DAWN | ×0.80 — enemies retreating | None |

The NOCTURNAL enemy type exists only in EnemyWave's type_weights dict during NIGHT phase.
Implementation: DayNightManager emits `phase_changed(phase: StringName)`. EnemyWave
connects and swaps its type_weights dict to a night-variant preset.

### 1.5 Resource Availability

| Resource | Time Restriction | Mechanism |
|---|---|---|
| GHOST_MUSHROOM (type 3) | Night only (NIGHT_START..NIGHT_END) | ResourceNode.setup() checks DayNightManager.current_phase; visible only at night |
| MOON_HERB (new type 42) | Night + clear weather only | Same check + weather flag |
| GOLDEN_SAP (type 14 WILD_HONEY) | Dawn window only (DAWN_START..DAY_START) | Node hides at DAY_START, reappears at DAWN_START |
| GLOWING_MUSHROOM (type 34) | Night intensifies glow; day still available | Night: rarity_glow alpha ×2.0, pulse speed ×3.0 |

Implementation: ResourceNode listens to DayNightManager.phase_changed. On phase change,
nodes call `_apply_phase_visibility()`. No polling — pure signal-driven.

### 1.6 NPC Schedules

| NPC Type | Day Behavior | Night Behavior |
|---|---|---|
| MERCHANT | Wander WANDER_HALF_RANGE=120, shop open | Stops walking, lamp sprite added, shop CLOSED popup |
| SCOUT | Normal wander | Hides (visible=false) — scouting danger |
| SAGE | Normal | Emits faint glow; grants 20% XP bonus (night study bonus) |
| BARD | Normal | Plays at night too, speed buff duration ×1.5 |
| HEALER | Normal | Heals twice per interaction at night |

MERCHANT CLOSED state: popup text says "Ferme pour la nuit — reviens a l'aube." No
purchase possible. This creates dawn anticipation (Stardew Valley shop timing loop).

### 1.7 Cave Entrances

CaveEntrance nodes (hidden_cave.gd) add a procedural glow sprite child at night:
- Day: entrance is a dark arch sprite, interact label "Entree obscure"
- Night: a pulsing cyan Sprite2D (modulate alpha: 0.4 + sin(t*2)*0.3) appears on top,
  interact label "Grotte lumineuse — Entrer". Glow costs 0 extra draw calls because
  it uses the same sprite child toggled visible.

### 1.8 Special Dawn and Dusk Events

**Dawn Window (DAWN_START → DAY_START, 38 seconds):**
- DayNightManager emits `dawn_event`. Main.gd spawns a roaming Merchant Caravan NPC
  (MERCHANT type, but with a unique wagon sprite and double inventory) at x=0, wanders
  rightward across the screen then disappears at x=48000. Session-unique — only one caravan
  per day.
- GOLDEN_SAP resource nodes become interactable. Window lasts exactly 38s.
- AudioManager layer "dawn_choir" cross-fades in (bell/bird tones) for 60 seconds.

**Dusk Window (DUSK_START → NIGHT_START, 48 seconds):**
- DayNightManager emits `dusk_event`. Active RPG enemy camps increase patrol radius ×1.5.
- All Bard NPCs play a farewell melody — their modulate alpha pulses bright then fades.
- HUD shows a small label "Tombe de la nuit..." (fades out after 3s via Tween).

---

## 2. Weather System

### 2.1 Design Reference

BOTW: weather affects combat (lightning on metal), forces player adaptation.
Don't Starve: storm = dangerous, night + storm = critical. Garrison: weather changes
resource availability and movement — never purely punishing, always with opportunity
tradeoff.

### 2.2 Six Weather States

```
enum WeatherState {
    CLEAR   = 0,
    CLOUDY  = 1,
    RAIN    = 2,
    STORM   = 3,
    FOG     = 4,
    BLIZZARD = 5,   # Snow zones only (Zone L and M: Tundra/Glacier)
}
```

### 2.3 Zone Weather Tables

Each zone has a `weather_weights: Array[float]` defining probability distribution across
the 6 states. WeatherManager rolls a new state every WEATHER_INTERVAL seconds (real time).

| Zone Type | CLEAR | CLOUDY | RAIN | STORM | FOG | BLIZZARD |
|---|---|---|---|---|---|---|
| Forest (A, F) | 0.40 | 0.30 | 0.20 | 0.05 | 0.05 | 0.00 |
| Swamp (E) | 0.15 | 0.20 | 0.30 | 0.10 | 0.25 | 0.00 |
| Desert (J) | 0.60 | 0.25 | 0.05 | 0.10 | 0.00 | 0.00 |
| Ruins (C, D) | 0.30 | 0.30 | 0.15 | 0.10 | 0.15 | 0.00 |
| Tundra (L, M) | 0.25 | 0.25 | 0.05 | 0.05 | 0.15 | 0.25 |
| Default | 0.45 | 0.30 | 0.15 | 0.05 | 0.05 | 0.00 |

WEATHER_INTERVAL = 180.0 seconds (3 real minutes). Transitions are always to an adjacent
state (CLEAR→CLOUDY, not CLEAR→STORM directly) — WeatherManager enforces adjacency graph:
```
CLEAR ↔ CLOUDY ↔ RAIN ↔ STORM
               ↕
              FOG
CLOUDY ↔ BLIZZARD (tundra zones only)
```

### 2.4 Per-Weather Effects

**CLEAR**
- Resource spawn rate: ×1.0
- Enemy types: standard zone weights
- Visibility: Camera limit none
- Hero speed: ×1.0
- Screen: no overlay

**CLOUDY**
- Resource spawn rate: ×0.9 (slightly fewer herbs — overcast)
- Enemy types: standard weights
- Visibility: none
- Hero speed: ×1.0
- Screen: white ColorRect overlay, alpha=0.08, soft diffuse look

**RAIN**
- Resource spawn rate: HERB ×1.5 (rain nourishes), WOOD ×0.8 (wet wood harder to chop)
- Enemy types: HEALER weight ×0.5 (healer avoids rain), INFANTRY weight ×1.2
- Visibility: none
- Hero speed: ×0.88 (wet ground)
- Screen: blue-gray overlay Color(0.25, 0.35, 0.55, 0.18) + rain particle system
  (GPUParticles2D, 120 particles, gravity downward, short lifetime 0.4s, 1 draw call)

**STORM**
- Resource spawn rate: ALL ×0.6 (dangerous to gather), SULFUR ×2.0 (storm brings sulfur
  to surface)
- Enemy types: Nocturnal weight ×1.3 even during day (storms darken sky)
- Visibility: camera limit none but overlay heavily darkens scene
- Hero speed: ×0.75
- Screen: dark blue-gray overlay Color(0.10, 0.12, 0.22, 0.45) + lightning flash events.
  Lightning: every 8–20s (random), a white full-screen flash ColorRect goes alpha 0.0→0.9→0.0
  over 0.15s via Tween. AudioManager plays a procedural low-frequency crack SFX.
  Rain particles: 250 count, faster velocity.

**FOG**
- Resource spawn rate: GHOST_MUSHROOM ×3.0 (fog = spores), FEATHER ×0.3 (birds hide)
- Enemy types: SCOUT excluded, HEALER weight ×1.5
- Visibility: FogManager adds a second overlay ColorRect with a radial vignette texture,
  Color(0.55, 0.55, 0.52, 0.60) — edges heavily obscured, center clear. This simulates
  limited sight range without a real camera crop (mobile-safe, 1 draw call).
- Hero speed: ×1.0 (fog doesn't slow movement)
- Screen: dense gray overlay + vignette

**BLIZZARD** (Tundra zones only)
- Resource spawn rate: ICE_CRYSTAL ×2.5, all others ×0.4
- Enemy types: Ice variant (existing CAVALIER with blue tint and speed ×0.7)
- Visibility: vignette like FOG but white Color(0.88, 0.92, 1.0, 0.70)
- Hero speed: ×0.65
- Screen: white overlay + snow particles (GPUParticles2D angled, 180 particles)
- Special: hero takes 1 HP damage every 10 real seconds without shelter (future HP system
  hook — DayNightManager emits `blizzard_tick` every 10s, hero.gd listens)

### 2.5 Weather Transition Visual

On every weather state change, WeatherManager cross-fades overlays:
```gdscript
# WeatherManager._transition_to(new_state):
var tween := create_tween()
tween.tween_property(_overlay, "color", WEATHER_COLORS[new_state], 4.0)
# Particle system: stop old emitter, start new emitter
_rain_particles.emitting = (new_state == WeatherState.RAIN or new_state == WeatherState.STORM)
_snow_particles.emitting = (new_state == WeatherState.BLIZZARD)
```

Transition duration: 4.0 seconds — visible but not jarring on mobile.

---

## 3. Season System

### 3.1 Season Duration

SEASON_DURATION_DAYS = 7 (real-world days). Measured via OS.get_unix_time() stored in
ConfigFile at session start. The game reads the stored start time on launch and computes
current season from elapsed real days. This is the ONE intentional ConfigFile use for
seasons — the season must persist across sessions to feel real.

```
season_index = (days_since_epoch / SEASON_DURATION_DAYS) % 4
```

Seasons rotate regardless of play time. A player who opens the game after 10 days skips
forward correctly.

```
enum Season {
    SPRING = 0,
    SUMMER = 1,
    AUTUMN = 2,
    WINTER = 3,
}
```

### 3.2 Zone Color Palette by Season

SeasonManager exports a `modulate` color applied to the GameWorld Node2D (all sprites
inherit it). This costs 0 extra draw calls — it uses Godot's built-in color inheritance.

| Season | GameWorld Modulate | Sky Overlay (2nd overlay) |
|---|---|---|
| SPRING | Color(0.96, 1.00, 0.92) — slight green tint | Color(0.72, 0.88, 1.0, 0.06) — pale sky blue |
| SUMMER | Color(1.00, 0.98, 0.85) — warm golden | Color(1.0, 0.95, 0.72, 0.05) — sunny |
| AUTUMN | Color(1.00, 0.88, 0.72) — amber | Color(0.85, 0.58, 0.28, 0.10) — orange sky |
| WINTER | Color(0.88, 0.92, 1.00) — cold blue-white | Color(0.78, 0.85, 1.0, 0.12) — blue haze |

These are subtle — world still reads clearly. Combined with zone-specific background
sprites swapped per season (see Section 3.3).

### 3.3 Zone Background Swaps (Per Season)

Each zone's ExplorationZone node holds four background texture paths. On season change,
SeasonManager calls `zone.set_season(season)` which swaps the Sprite2D texture.

Example for Forest Zone A:
```
BG_TEXTURES = {
    Season.SPRING: "res://assets/sprites/zones/forest_spring.png",
    Season.SUMMER: "res://assets/sprites/zones/forest_summer.png",
    Season.AUTUMN: "res://assets/sprites/zones/forest_autumn.png",
    Season.WINTER: "res://assets/sprites/zones/forest_winter.png",
}
```

Winter forest background: bare grey trees, snow patches. Autumn: red/orange canopy.
Spring: fresh light-green leaves, flowers. Summer: dense dark-green canopy.

### 3.4 Resource Changes by Season

| Resource | Spring | Summer | Autumn | Winter |
|---|---|---|---|---|
| HERB | ×1.5 | ×1.0 | ×0.7 | ×0.0 (none — frozen) |
| WILD_BERRY | ×0.5 | ×2.0 | ×1.5 | ×0.0 |
| ACORN | ×0.0 | ×0.5 | ×3.0 | ×0.5 (frozen ground) |
| ICE_CRYSTAL | ×0.0 | ×0.0 | ×0.5 | ×3.0 |
| WILD_HONEY | ×1.0 | ×2.0 | ×1.5 | ×0.0 |
| MUSHROOM | ×1.0 | ×0.8 | ×2.5 | ×0.5 |
| WOOD | ×1.0 | ×0.9 | ×1.2 | ×1.5 (dry firewood demand) |

These multipliers are applied to ResourceNode spawn counts when ExplorationMap builds
the zone's node list at session entry. ResourceNodeTimed uses them for respawn yield.

### 3.5 NPC Dialogue by Season

Each NPC type has a seasonal greeting line (string array indexed by Season):

MERCHANT seasonal:
- SPRING: "Les prix remontent comme les fleurs!"
- SUMMER: "Journee parfaite pour faire du commerce."
- AUTUMN: "Les reserves d'hiver se remplissent — j'achete tout."
- WINTER: "Ma plus belle cargaison contre un peu de chaleur..."

SAGE seasonal:
- SPRING: "Le monde renaît. Voici ce que les anciens savaient..."
- SUMMER: "La chaleur reveille les vieilles magies."
- AUTUMN: "Les feuilles tombent. Chaque chose a sa fin."
- WINTER: "Dans le silence de la neige, les etoiles parlent."

### 3.6 Seasonal Special Events

Events fire once per season (ConfigFile flag prevents re-triggering within the same
season). SeasonManager checks on session start.

**SPRING — Festival des Semailles (Spring Sowing Festival)**
- Trigger: Season.SPRING + first session of the season
- Effect: All resource nodes spawn ×2.0 count for this session. A special BARD NPC
  (unique green cloak sprite variant) appears at x=2000 with a 60s dance animation
  (sprite flip_h oscillating, +0.3 modulate alpha pulse). Interacting gives the hero
  +200 XP and 50 gold. Duration: single session.
- Visual: Spring sparkle GPUParticles2D (40 white dots, float upward) placed at festival
  NPC position.

**SUMMER — La Grande Chasse (Great Hunt)**
- Trigger: Season.SUMMER + first session of the season
- Effect: All RPG enemy camps have ×1.5 spawn count and drop double loot this session.
  A SCOUT NPC appears with the quest marker ("!") above head — interacting opens the
  "Chasse" contract: "Elimine 10 camps cette saison" stored in ContractBoard.
- Duration: tracks across sessions via ConfigFile counter ("summer_hunt_kills" key).

**AUTUMN — Moisson d'Automne (Autumn Harvest)**
- Trigger: Season.AUTUMN + first session of the season
- Effect: Merchant sells all items at 25% discount this session. A special colored
  harvest chest (orange tint on chest.png) appears at the center of each zone — unique
  loot (one guaranteed RARE resource). Chest disappears after collect (session-scoped).
- Visual: Falling leaves GPUParticles2D (60 orange/red polygons, slow drift, low gravity).

**WINTER — Solstice d'Hiver (Winter Solstice)**
- Trigger: Season.WINTER + day 3-4 of season (mid-winter, more precise feel)
- Effect: All cave entrances open simultaneously (no unlock needed). A hidden zone boss
  (NOCTURNAL variant with ×3.0 HP, unique silver modulate) spawns in Zone L. Killing it
  grants the "Lame d'Hiver" item (stored in ItemInventory). Night phase lasts 30% longer
  this session (NIGHT_END pushed to 1.10, normalized to wrap).
- Visual: Aurora effect on sky overlay — ColorRect slowly cycles hue from green to purple
  using Tween `tween_property(overlay, "color", ...)` loop every 8 seconds.

---

## 4. World State Progression

### 4.1 Design Reference

Dark Souls: world changes permanently as bosses fall. Don't Starve: base building changes
the starting zone. Garrison: cleared camps = safer zones = settlement growth = faster
resources. Classic positive feedback loop rewarding exploration.

### 4.2 Zone States

```
enum ZoneState {
    WILD      = 0,  # Default: enemy camps active, resources normal rate
    CONTESTED = 1,  # 50% camps cleared: some enemies remain
    PACIFIED  = 2,  # All camps cleared: no enemies spawn, friendly NPCs settle
    FLOURISHING = 3,  # Pacified + player visited 3+ times: resources at peak
}
```

ZoneStateManager tracks per-zone state in a `zone_states: Array[int]` (15 entries,
session-scoped initially, ConfigFile-persistent for release).

### 4.3 Zone State Visual Changes

**WILD:** Standard zone appearance. Enemy camp sprites at full opacity. Red skull icon
on ExplorationMap zone thumbnail (HUD minimap).

**CONTESTED:** Camp sprites reduced to 70% opacity (fighting ongoing look). Camp fires
still lit. Yellow warning icon on minimap.

**PACIFIED:**
- All enemy camp sprites replaced with "ruins" variant: same base rock/wood sprite but
  desaturated (modulate.s reduced by 60%) and with an added scorch-mark decal sprite
  (ColorRect dark brown, 80×20px, z_index=-1) beneath the camp.
- GameWorld Node2D receives a +0.08 additive brightness boost (modulate value, clamped).
- Friendly SETTLER NPC spawns at the former camp position (type = MERCHANT, forced
  dialog "Enfin en securite ici!"). Stays permanently.
- Resource nodes respawn at ×1.4 base rate (ResourceNodeTimed.respawn_time ×0.70).
- Green shield icon on minimap.

**FLOURISHING:**
- Zone receives an additional +0.05 brightness boost on top of PACIFIED.
- Two SETTLER NPCs. One is always a HEALER.
- New unique resource node type spawns: CULTIVATION (type 43 — crops grown by settlers,
  yield ×1.5 HERB). Node returns daily (dawn timer).
- Gold star icon on minimap.

### 4.4 Pacification Trigger

`rpg_enemy_camp.gd` emits `camp_cleared(camp_id: int, zone_id: int)`. ZoneStateManager
receives this, increments `zone_cleared_counts[zone_id]`, and recomputes the zone state:
```
if cleared >= total_camps * 1.0:  state = PACIFIED
elif cleared >= total_camps * 0.5: state = CONTESTED
```

Signal chain: `camp_cleared` → ZoneStateManager → `zone_state_changed(zone_id, new_state)`
→ ExplorationMap updates camp sprites → spawns settlers → ResourceNodeTimed refreshes
respawn times.

### 4.5 Visual Feedback on State Change

When zone transitions to PACIFIED:
1. Full-screen ColorRect flashes Color(0.9, 1.0, 0.8, 0.0) → alpha 0.35 → 0.0 over 1.2s
   (Tween — same pattern as lightning flash).
2. HUD banner: "Zone pacifiee!" label appears at top center for 3 seconds then fades.
3. AudioManager plays a new "pacify" SFX (rising chord, 0.8s, procedural WAV).

---

## 5. Ambient Life System

### 5.1 Design Reference

Minecraft: ambient animals graze at distance. Stardew Valley: crows in crops, butterflies
near flowers. Goal: 50+ ambient entities visible at any time, 0 gameplay logic, never
exceeds 8 draw calls total (pool + sprites share texture atlas).

### 5.2 Entity Types

| Entity | Zone Affinity | Behavior |
|---|---|---|
| BIRD | Forest, Plains | Fly across camera from left/right, random Y, lifetime 4-8s |
| BUTTERFLY | Spring/Summer Forest | Float in small figure-8 pattern, near flowers, 6-12s |
| BEE | Summer zones | Buzz between resource nodes, fast zigzag, 3s lifetime |
| FISH | Water zones (Zone H: Lac) | Drift horizontally just below water surface |
| FROG | Swamp (Zone E) | Hop in arcs, short lifetime, hop every 2-4s |
| LEAF | Autumn/Wind weather | Float diagonally downward, 8-15s lifetime |
| SNOWFLAKE | Winter/Blizzard | Drift slowly, 10-20s lifetime |
| FIREFLY | Night only | Slow drift with flickering alpha, all zones |
| CROW | Ruins (Zone C, D) | Circle slowly overhead, 8-12s, counter-clockwise |

### 5.3 Performance Architecture

**Core Rule: Only spawn entities inside the camera frustum + a 120px margin.**

AmbientLifeManager (Node2D, added to GameWorld) uses an ObjectPool of 64 Node2D sprites
total across all entity types. On `_process(delta)`:

Step 1: every 0.25s (not every frame), compute the camera viewport rect:
```gdscript
# camera_rect is updated every 15 frames (every 0.25s at 60fps)
var cam: Camera2D = _camera_node
var cam_pos: Vector2 = cam.global_position
var half_vp: Vector2 = get_viewport().get_visible_rect().size * 0.5 / cam.zoom
_frustum_rect = Rect2(cam_pos - half_vp - Vector2(120, 120),
                      (half_vp + Vector2(120, 120)) * 2.0)
```

Step 2: every 0.5s, if active_entity_count < TARGET_COUNT[current_zone_type],
checkout a pooled sprite and place it at a random position within _frustum_rect on
the appropriate edge (birds: top edge flying downward or left/right edge flying across).

Step 3: each active entity's `_process` runs its simple behavior (linear movement,
sine wave for butterflies, hop arc for frogs). When lifetime expires or entity exits
a 200px-extended frustum, it is returned to pool via `return_node()`.

TARGET_COUNT by zone type:
```
FOREST: 20 entities (8 birds, 6 butterflies, 4 bees, 2 leaves)
SWAMP:  15 entities (5 frogs, 5 birds, 5 fireflies at night)
WATER:  18 entities (12 fish, 4 birds, 2 frogs)
RUINS:  10 entities (6 crows, 4 leaves)
TUNDRA: 12 entities (8 snowflakes, 4 birds)
DEFAULT: 15 entities (10 birds, 5 butterflies)
```

Total pool: 64 nodes (covers TARGET_COUNT for any single zone with 20% overhead).

### 5.4 Sprite Implementation

All ambient entity sprites use Sprite2D with a shared 512×512 sprite atlas
(`res://assets/sprites/ambient/ambient_atlas.png`). Each entity type maps to a
region in the atlas (atlas_coords + region_rect on the Sprite2D). This collapses
all 64 ambient sprites to exactly 1 draw call (same texture, no state change between
batched draws). Godot 4 batches Sprite2D with identical textures automatically in
GL Compatibility mode.

Entity atlas layout (64×64 tiles in a 512×512 atlas = 64 slots):
- Row 0: bird frames (4 frames × 8 tints = 32 slots)
- Row 1: butterfly (4f), bee (4f), frog (4f), fish (4f), leaf variants (4f), snowflake (4f)
  crow (4f), firefly (4f), spare (8s)

For the MVP without final assets, entities use simple ColorRect fallback shapes (no
atlas required). The pool and frustum architecture is the same.

### 5.5 Behavior Details Per Entity Type

**BIRD:**
```gdscript
# Spawned at left or right edge of frustum, random Y in [frustum.top+50, frustum.bottom-50]
# Velocity: Vector2(±150.0 to ±220.0, randf_range(-20, 20))
# Lifetime: randf_range(4.0, 8.0)
# Scale oscillates: scale.y = 1.0 + sin(t * 8.0) * 0.08  (wing flap)
```

**BUTTERFLY:**
```gdscript
# Spawned near a random resource node or flower decor within frustum
# Figure-8 path: pos = anchor + Vector2(sin(t*1.5)*40, sin(t*3.0)*20)
# Very slow drift: anchor moves at Vector2(8.0, 0) per second
# Lifetime: randf_range(6.0, 12.0)
```

**FIREFLY (night only):**
```gdscript
# Spawned randomly within frustum, any position
# Slow drift: velocity = Vector2(randf_range(-15,15), randf_range(-10,10))
# Alpha flicker: modulate.a = 0.4 + sin(t * randf_range(3.0, 7.0)) * 0.5
# Color: Color(0.8, 1.0, 0.4)  — yellow-green
# Lifetime: randf_range(8.0, 15.0)
```

**FROG:**
```gdscript
# Hop arc: every HOP_INTERVAL (randf_range(2.0,4.0)) seconds, begin hop
# Hop: position follows parabola over 0.4s, height 30px, distance ±60px X
# Idle: sprite visible, scale.y bobs ±0.05 slowly
```

---

## 6. Procedural Ambient Audio

### 6.1 Design Reference

Stardew Valley: distinct zone music. BOTW: dynamic music that blends. Garrison: no
music in the traditional sense (mobile battery concern, file size) — instead, layered
procedural soundscapes generated via AudioStreamWAV PCM (same technique as existing
AudioManager SFX).

### 6.2 Architecture

ZoneAudioManager (autoload, extends Node) owns 6 persistent AudioStreamPlayer nodes
(layers). Each layer is a looping stream representing one sonic element. Volume per
layer is lerped based on hero's proximity to zone type boundaries.

```
enum AudioLayer {
    WIND     = 0,   # Constant low whoosh — all zones, volume varies
    BIRDS    = 1,   # Bird calls — forest/plains
    RAIN_AMB = 2,   # Rain ambience — weather dependent
    INSECTS  = 3,   # Crickets/frogs — night/swamp
    CAVE     = 4,   # Cave drip — underground zones
    FIRE     = 5,   # Camp fires crackling — near enemy camps / TD zone
}
```

All 6 AudioStreamPlayer nodes active at all times. Volume lerps to 0 when the layer
is not relevant. This avoids any `play()/stop()` overhead (no pops, no delay).

Volume lerp: `1.0 - pow(1.0 - 0.03, delta * 60.0)` — smooth cross-fade over ~1 second.

### 6.3 Zone Audio Profiles

Each zone type (15 zones mapped to zone_types) exports a `audio_targets: Dictionary`
with target volume_db per AudioLayer:

```
ZONE_AUDIO = {
    "forest": {
        AudioLayer.WIND:     -8.0,
        AudioLayer.BIRDS:    -3.0,
        AudioLayer.RAIN_AMB: -80.0,  # silent unless weather = RAIN
        AudioLayer.INSECTS:  -14.0,  # forest has some insects
        AudioLayer.CAVE:     -80.0,
        AudioLayer.FIRE:     -80.0,
    },
    "swamp": {
        AudioLayer.WIND:     -14.0,
        AudioLayer.BIRDS:    -20.0,
        AudioLayer.RAIN_AMB: -6.0,   # swamp sounds like constant light rain
        AudioLayer.INSECTS:  -2.0,   # frogs, crickets dominate
        AudioLayer.CAVE:     -80.0,
        AudioLayer.FIRE:     -80.0,
    },
    "cave": {
        AudioLayer.WIND:     -6.0,   # howling cave wind
        AudioLayer.BIRDS:    -80.0,
        AudioLayer.RAIN_AMB: -80.0,
        AudioLayer.INSECTS:  -18.0,  # distant dripping insects
        AudioLayer.CAVE:     -2.0,   # primary layer
        AudioLayer.FIRE:     -80.0,
    },
    "ruins": {
        AudioLayer.WIND:     -4.0,   # wind through broken walls
        AudioLayer.BIRDS:    -15.0,  # crows
        AudioLayer.RAIN_AMB: -80.0,
        AudioLayer.INSECTS:  -20.0,
        AudioLayer.CAVE:     -12.0,  # underground ruins feel
        AudioLayer.FIRE:     -80.0,
    },
    "td_garrison": {
        AudioLayer.WIND:     -18.0,
        AudioLayer.BIRDS:    -80.0,
        AudioLayer.RAIN_AMB: -80.0,
        AudioLayer.INSECTS:  -80.0,
        AudioLayer.CAVE:     -80.0,
        AudioLayer.FIRE:     -4.0,   # camp fires, forge
    },
}
```

### 6.4 Zone Blending

Hero's world X position determines which zone is "active" and with what blend weight.
Zones are laid out in X bands (0-3200 = Zone A, 3200-6400 = Zone B, etc. across
48000px width).

```gdscript
# ZoneAudioManager._process():
var hero_x: float = _hero_node.global_position.x
var zone_a_id := int(hero_x / ZONE_WIDTH)  # which zone we're in
var zone_b_id := zone_a_id + 1             # next zone
var blend := fmod(hero_x, ZONE_WIDTH) / ZONE_WIDTH  # 0.0=full zone_a, 1.0=full zone_b

var profile_a: Dictionary = _get_zone_profile(zone_a_id)
var profile_b: Dictionary = _get_zone_profile(zone_b_id)
for layer in AudioLayer.values():
    var target_db: float = lerpf(profile_a[layer], profile_b[layer], blend)
    # Apply weather and time modifiers
    target_db += _weather_db_offset(layer, WeatherManager.current_state)
    target_db += _night_db_offset(layer, DayNightManager.current_phase)
    # Lerp current volume toward target
    var w := 1.0 - pow(1.0 - 0.03, delta * 60.0)
    _players[layer].volume_db = lerpf(_players[layer].volume_db, target_db, w)
```

### 6.5 Weather Audio Modifiers (per layer, in dB)

| Weather | WIND | RAIN_AMB | INSECTS | BIRDS |
|---|---|---|---|---|
| CLEAR | +0 | -80 | +0 | +0 |
| CLOUDY | +3 | -80 | -3 | -2 |
| RAIN | +5 | +12 | -8 | -10 |
| STORM | +12 | +18 | -80 | -80 |
| FOG | -2 | -6 | +5 | -5 |
| BLIZZARD | +15 | +10 | -80 | -80 |

### 6.6 Night Audio Modifiers (per layer, in dB)

| Phase | WIND | BIRDS | INSECTS | FIRE |
|---|---|---|---|---|
| DAY | +0 | +0 | -8 | +0 |
| DUSK | +2 | -4 | +3 | +2 |
| NIGHT | +4 | -80 | +8 | +3 |
| DAWN | +0 | +5 | -4 | -2 |

### 6.7 Procedural Audio Streams

All 6 layer streams are generated procedurally via AudioStreamWAV PCM at 11025 Hz,
same as existing AudioManager SFX. Each is a looping stream (~4-8 seconds duration).
They are generated once in ZoneAudioManager._ready() and never recreated.

Key generation techniques (extending existing `_make_sfx_*` patterns):

**WIND layer (6.5s):**
```gdscript
# Filtered noise: two sine LFOs at 0.3Hz and 0.7Hz modulate noise amplitude
# Creates slow "breathing" wind texture
var lfo1 = sin(TAU * 0.3 * t)
var lfo2 = sin(TAU * 0.7 * t + 1.3)
var env = 0.3 + (lfo1 * 0.2 + lfo2 * 0.15)
data[i] = int(clamp(128.0 + randf_range(-1.0, 1.0) * env * 80.0, 0.0, 255.0))
```

**BIRDS layer (4.0s):**
```gdscript
# Three chirp patterns: freq sweep 1200→1800Hz, 0.08s, at t=0.5s, 1.8s, 3.2s
# Between chirps: very quiet wind noise
```

**RAIN_AMB layer (3.0s):**
```gdscript
# Dense noise, flat envelope, slight high-pass (reduce low amplitude samples)
# Layered with sparse "drop impact" clicks (sample spike at random intervals)
```

**INSECTS layer (5.0s, looping):**
```gdscript
# Repeating chirp: 2800Hz square wave, 0.015s on, 0.035s off, group of 8, pause 0.3s
# Simulates cricket rhythm pattern
```

**CAVE layer (8.0s):**
```gdscript
# Sparse water drip: sine wave 220Hz, 0.06s, exponential decay, at t=1.2, 3.4, 6.1s
# Background: very quiet low-frequency rumble (60Hz sine, amplitude 0.04)
```

**FIRE layer (4.5s):**
```gdscript
# Noise with 1/f characteristic: low freq components stronger than high
# Achieved by: noise[i] = noise[i-1] * 0.85 + randf_range(-1,1) * 0.15
# Creates warm crackling texture
```

---

## 7. World Memory

### 7.1 Design Reference

Dark Souls: every bonfire lit, every fog gate cleared, every NPC killed stays that way
forever. Terraria: biome corruption spreads session-to-session. For Garrison MVP, most
world memory is session-scoped (already established ADR-009). Persistent memory is limited
to 4 categories stored in ConfigFile.

### 7.2 Session-Scoped Memory (Reset on New Game)

All of the following are stored in runtime Dictionary/Array autoloads, cleared by
GameStateMachine.session_reset signal:

| Memory Type | Storage | Access Pattern |
|---|---|---|
| Chopped tree stumps | `WorldMemory.tree_states: Dictionary` (node_id → bool) | ResourceNode calls `WorldMemory.mark_chopped(id)` on collect |
| Cleared caves (open state) | `WorldMemory.cave_states: Dictionary` (cave_id → bool) | HiddenCave calls `WorldMemory.mark_cave_opened(id)` |
| Defeated camps | `WorldMemory.camp_states: Dictionary` (camp_id → int cleared_count) | RpgEnemyCamp updates on defeat |
| Previously met NPCs | `WorldMemory.met_npcs: Array[int]` (npc_ids) | NpcWanderer calls `WorldMemory.mark_met(id)` on first interaction |
| Opened chests | `WorldMemory.opened_chests: Array[int]` (chest_ids) | TreasureChest marks after collect |
| Zone visit counts | `WorldMemory.zone_visits: Array[int]` (15 entries) | ExplorationMap increments on enter |

### 7.3 ConfigFile-Persistent Memory (Survives Sessions)

ADR-009 forbids FileAccess in MVP. The world memory upgrade for release uses ConfigFile
(which is explicitly permitted in post-MVP). Four categories persist:

```
ConfigFile path: "user://world_memory.cfg"

[seasons]
season_start_unix = <int>         # When season system started (for current season calc)
spring_festival_done = <bool>     # Per-season event flags
summer_hunt_kills = <int>         # Cross-session kill counter for summer hunt
autumn_harvest_done = <bool>
winter_solstice_done = <bool>
winter_blade_item_unlocked = <bool>

[zone_states]
zone_0_state = <int>              # ZoneState enum value per zone (0-14)
zone_0_cleared_count = <int>
# ... repeated for all 15 zones

[hero_encounters]
npc_merchant_met = <bool>         # Permanent "you've met before" flags
npc_scout_met = <bool>
# Per named NPC (future: named NPCs have unique IDs)

[summer_hunt]
camps_cleared_this_season = <int>
hunt_contract_complete = <bool>
```

ConfigFile is read once at game start and written on:
- Session end (app background/quit — via `get_tree().auto_accept_quit` override)
- After any seasonal event completion
- After any zone state change to PACIFIED or FLOURISHING

### 7.4 Visual Representations of Memory

**Chopped tree stump:** ResourceNode on collect sets `visible = false` (already
implemented). WorldMemory stores the node's unique position as a key. When ExplorationMap
rebuilds the zone, it checks WorldMemory before spawning each node. If marked: spawn
a "stump" Sprite2D (scaled tree_sm.png at 0.3, desaturated) instead of the live node.

**Open cave entrance:** HiddenCave's open state is persisted in WorldMemory. On zone
rebuild, cave spawns in "open" visual state (arch sprite + no fog-of-war overlay) if
`WorldMemory.cave_states[id]` is true. No lock interaction shown.

**Defeated camp ruins:** ZoneStateManager drives this (Section 4.3). Camps in CONTESTED
or PACIFIED zones render with their desaturated ruins sprite. Camp fires are extinguished
(fire Sprite2D hidden).

**Previously met NPCs:** On first interaction, NpcWanderer calls
`WorldMemory.mark_met(npc_id)`. On subsequent interactions, popup greeting changes:
- First time: "Salut etranger, je suis [NAME]..."
- Subsequent: "Ah, [Hero Name]! Tu es revenu."
This is entirely string lookup — no extra draw calls, no node changes.

**Cleared camp ruins:** Implemented in Section 4.3. The scorch mark decal + desaturated
sprite are the permanent visual. Settler NPCs placed at the position remain in
`_expl_interactables` list.

### 7.5 WorldMemory Autoload

```gdscript
## WorldMemory — session-scoped world state registry.
## ConfigFile persistence handled by WorldMemoryPersistence (separate autoload, post-MVP).
## ADR-009 compatible: no FileAccess in MVP. This class stores session memory only.
extends Node

## Chopped resource nodes — keyed by Vector2i(world_pos / 10) for collision tolerance.
var tree_states: Dictionary = {}
var cave_states: Dictionary = {}
var camp_states: Dictionary = {}
var met_npcs: Array[int] = []
var opened_chests: Array[int] = []
var zone_visits: Array[int] = []  # [0..14]

func _ready() -> void:
    zone_visits.resize(15)
    zone_visits.fill(0)
    GameStateMachine.session_reset.connect(_on_session_reset)

func mark_chopped(world_pos: Vector2) -> void:
    tree_states[Vector2i(world_pos / 10.0)] = true

func is_chopped(world_pos: Vector2) -> bool:
    return tree_states.get(Vector2i(world_pos / 10.0), false)

func mark_cave_opened(cave_id: int) -> void:
    cave_states[cave_id] = true

func is_cave_open(cave_id: int) -> bool:
    return cave_states.get(cave_id, false)

func mark_met(npc_id: int) -> void:
    if npc_id not in met_npcs:
        met_npcs.append(npc_id)

func has_met(npc_id: int) -> bool:
    return npc_id in met_npcs

func mark_chest_opened(chest_id: int) -> void:
    if chest_id not in opened_chests:
        opened_chests.append(chest_id)

func is_chest_open(chest_id: int) -> bool:
    return chest_id in opened_chests

func record_zone_visit(zone_id: int) -> void:
    if zone_id >= 0 and zone_id < zone_visits.size():
        zone_visits[zone_id] += 1

func get_zone_visits(zone_id: int) -> int:
    if zone_id >= 0 and zone_id < zone_visits.size():
        return zone_visits[zone_id]
    return 0

func _on_session_reset() -> void:
    tree_states.clear()
    cave_states.clear()
    camp_states.clear()
    met_npcs.clear()
    opened_chests.clear()
    zone_visits.fill(0)
```

---

## 8. System Interconnections

### 8.1 Signal Graph

```
DayNightManager
  ├─ phase_changed(phase) → EnemyWave (swap type_weights)
  ├─ phase_changed(phase) → NpcWanderer (schedule update)
  ├─ phase_changed(phase) → ResourceNode (time-gated visibility)
  ├─ phase_changed(phase) → AmbientLifeManager (firefly enable/disable)
  ├─ phase_changed(phase) → ZoneAudioManager (night audio modifiers)
  ├─ phase_changed(phase) → CaveEntrance (glow toggle)
  ├─ dawn_event → Main (spawn caravan NPC)
  └─ dusk_event → Main (boost camp patrol radius)

WeatherManager
  ├─ weather_changed(state, zone_id) → ResourceNode (spawn rate modifier)
  ├─ weather_changed(state, zone_id) → ZoneAudioManager (weather audio modifiers)
  ├─ weather_changed(state, zone_id) → AmbientLifeManager (particle toggle)
  └─ weather_changed(state, zone_id) → HeroMovement (speed modifier)

SeasonManager
  ├─ season_changed(season) → ExplorationZone (background texture swap)
  ├─ season_changed(season) → GameWorld (modulate color change)
  ├─ season_changed(season) → ResourceNode (seasonal spawn multipliers)
  ├─ season_changed(season) → NpcWanderer (seasonal dialogue)
  └─ season_event_fired(event_id) → Main (spawn seasonal NPC/chest/event)

ZoneStateManager
  ├─ zone_state_changed(zone_id, state) → ExplorationMap (minimap icon)
  ├─ zone_state_changed(zone_id, state) → RpgEnemyCamp (sprite update)
  ├─ zone_state_changed(zone_id, state) → ResourceNodeTimed (respawn rate)
  └─ zone_state_changed(zone_id, state) → Main (settler NPC spawn)

AmbientLifeManager (internal — no outgoing signals)

ZoneAudioManager (reads from DayNightManager and WeatherManager, no signals)

WorldMemory
  └─ GameStateMachine.session_reset → _on_session_reset()
```

### 8.2 Draw Call Budget

| System | Draw Calls |
|---|---|
| Background sprite | 1 |
| Zone decor sprites | ~15 |
| Resource nodes (visible in camera) | ~12 |
| Enemy camps | ~8 |
| NPCs | ~6 |
| Hero + castle + towers | ~10 |
| HUD (CanvasLayer) | ~18 |
| Day/Night overlay | 1 |
| Weather overlay | 1 |
| Weather particles | 1 |
| Ambient life (64 sprites, same atlas) | 1 |
| Ambient audio (0 visual) | 0 |
| Seasonal overlay | 1 |
| **TOTAL** | **~75** |

Budget ceiling is 150. The living world systems add exactly 5 draw calls (3 overlays +
1 particle system + 1 ambient life batch) over the base scene. Well within budget.

---

## 9. Implementation Order

Recommended sprint sequencing:

1. **WorldMemory autoload** (no dependencies, pure data) — 0.5 day
2. **DayNightManager autoload** — color overlay + phase signal — 1 day
3. **WeatherManager autoload** — state machine + overlay — 1 day
4. **SeasonManager autoload** — ConfigFile read + modulate — 1 day
5. **ZoneStateManager autoload** — connects to existing camp_cleared signals — 1 day
6. **AmbientLifeManager** — pool + frustum logic — 1.5 days
7. **ZoneAudioManager** — 6 procedural layers + volume lerp — 1.5 days
8. **Wire all signals in Main.gd** — 0.5 day
9. **ResourceNode time/weather/season hooks** — 1 day
10. **NpcWanderer schedule + dialogue hooks** — 0.5 day

**Total estimate: ~9 developer days.**

---

## 10. Tuning Knobs

| Constant | Location | Default | Notes |
|---|---|---|---|
| DAY_DURATION_SECONDS | DayNightManager | 480.0 | Increase for slower pace |
| WEATHER_INTERVAL | WeatherManager | 180.0 | Decrease for dynamic weather |
| SEASON_DURATION_DAYS | SeasonManager | 7 | Must be integer |
| AMBIENT_TARGET_COUNT | AmbientLifeManager | see Section 5.3 | Reduce if draw calls high |
| AMBIENT_SPAWN_INTERVAL | AmbientLifeManager | 0.5s | Increase if CPU high |
| PACIFY_THRESHOLD | ZoneStateManager | 1.0 (all camps) | Reduce to 0.75 for easier pacification |
| FLOURISHING_VISIT_COUNT | ZoneStateManager | 3 | Visits needed to flourish |
| WEATHER_TRANSITION_DURATION | WeatherManager | 4.0s | Cross-fade speed |
| AUDIO_LERP_FACTOR | ZoneAudioManager | 0.03 | Volume cross-fade speed |

---

## 11. Acceptance Criteria

All items below must be verifiable before Living World is considered shipped:

- AC-LW-01: Day/Night cycle completes one full rotation in 8 ±0.5 real minutes
- AC-LW-02: Ambient overlay color changes visibly across all 4 phases
- AC-LW-03: GHOST_MUSHROOM resource nodes are invisible during DAY, visible during NIGHT
- AC-LW-04: MERCHANT NPC shows CLOSED popup at night and OPEN popup during day
- AC-LW-05: Cave entrances show glow sprite exclusively during NIGHT phase
- AC-LW-06: Weather transitions over 4s with no frame drop below 55fps
- AC-LW-07: Rain particle system active during RAIN and STORM states only
- AC-LW-08: STORM shows lightning flash (white) with 8-20s random interval
- AC-LW-09: Season changes GameWorld modulate color visibly between all 4 seasons
- AC-LW-10: Spring Festival event spawns exactly once per Spring season per ConfigFile flag
- AC-LW-11: PACIFIED zone shows desaturated camp sprite + settler NPC
- AC-LW-12: PACIFIED zone ResourceNodeTimed respawns 30% faster than WILD zone
- AC-LW-13: Ambient entities (birds, etc.) are visible only within camera frustum + 120px
- AC-LW-14: Ambient life pool never exceeds 64 simultaneous active nodes
- AC-LW-15: Total draw calls in exploration mode do not exceed 150
- AC-LW-16: Zone audio cross-fades smoothly as hero walks between zone X bands
- AC-LW-17: Wind audio layer volume rises during STORM weather
- AC-LW-18: Chopped tree node renders as stump on zone re-entry within same session
- AC-LW-19: "Previously met" NPC shows alternate greeting on second interaction
- AC-LW-20: WorldMemory clears completely on GameStateMachine.session_reset

---

## Dependencies

- `src/autoloads/game_state_machine.gd` — session_reset signal (existing)
- `src/autoloads/audio_manager.gd` — procedural WAV generation pattern (existing)
- `src/autoloads/resource_inventory.gd` — resource type constants (existing)
- `src/gameplay/resource_node.gd` — extend with `_apply_phase_visibility()` (existing)
- `src/gameplay/npc_wanderer.gd` — extend with schedule and seasonal dialogue (existing)
- `src/gameplay/hidden_cave.gd` — extend with night glow child sprite (existing)
- `src/gameplay/rpg_enemy_camp.gd` — emits camp_cleared signal (existing)
- `src/gameplay/object_pool.gd` — reused for ambient life pool (existing)
- New autoloads to create: WorldMemory, DayNightManager, WeatherManager,
  SeasonManager, ZoneStateManager, ZoneAudioManager, AmbientLifeManager
