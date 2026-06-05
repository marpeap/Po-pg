# RPG Exploration Map — Redesign Specification
## Version 2.0 — Complete Ground-Up Rework

**Context**: The current exploration map is a 48000×2160 horizontal band with 3 fixed Y-lanes.
This is not an RPG map — it is a scrolling corridor. This document specifies a complete rebuild
into a proper 2D world map, modeled on classic top-down RPG principles (ALTTP, Stardew Valley, FFXV
field maps, Secret of Mana). Every section below is self-contained and must be implemented fully
before moving to the next.

---

## SECTION 1 — WORLD ARCHITECTURE

### 1.1 Philosophy
A classic 2D RPG overworld has three qualities:
1. **Spatial coherence** — each area occupies a distinct 2D region. The player can go north, south,
   east, west. Danger increases as the player moves further from the starting area.
2. **Visual identity** — each zone looks different from its neighbors. Color, decoration density,
   and prop types change as the player crosses zone boundaries.
3. **Density** — no empty corridors. Every 200px radius circle should contain something of interest:
   a resource node, a decoration prop, an enemy patrol, or a landmark.

### 1.2 World Dimensions
| Parameter | Value | Rationale |
|-----------|-------|-----------|
| World width  | 9600 px | 5 zones × 1920 px/zone = 10× viewport width |
| World height | 3240 px | 3 zones × 1080 px/zone = 6× viewport height |
| Zone width   | 1920 px | Exactly 2× viewport — requires left/right pan to explore |
| Zone height  | 1080 px | Exactly 2× viewport — requires up/down pan to explore |
| Viewport     | 960×540 | Unchanged |

A 1920×1080 zone means the player sees exactly 25% of the zone from any fixed position. They
must move to explore it. This is the same "one-and-a-half screen" feel as classic Zelda zones.

### 1.3 Zone Grid Layout (5 columns × 3 rows = 15 zones)

```
Col→    0             1             2             3             4
Row↓  x=0-1919      x=1920-3839   x=3840-5759   x=5760-7679   x=7680-9599
       y=0-1079      y=0-1079      y=0-1079      y=0-1079      y=0-1079
  0  [FORET EVEIL] [CLAIRIERE  ] [RUINES      ] [CATACOMBES  ] [MARECAGE    ]
       y=1080-2159  y=1080-2159   y=1080-2159   y=1080-2159   y=1080-2159
  1  [FORET CRISTAL][CENDRES   ] [VALLEE FEU  ] [TOUNDRA     ] [DESERT      ]
       y=2160-3239  y=2160-3239   y=2160-3239   y=2160-3239   y=2160-3239
  2  [TEMPLE SACRE][GROTTES    ] [PICS ETHERES] [NECROPOLE   ] [CIME SACREE ]
```

**Zone index formula**: `zone_idx = row * 5 + col`
**Reverse**: `col = zone_idx % 5`, `row = zone_idx / 5`
**Zone origin** (top-left corner): `Vector2(col * 1920.0, row * 1080.0)`
**Zone center**: `zone_origin + Vector2(960.0, 540.0)`

### 1.4 Difficulty Progression
Difficulty increases with distance from the starting zone (zone 0, top-left corner):
- **Row 0** (y=0–1079): Safe/Early — zones 0-4. No danger flag. Weak enemies (tier 0).
- **Row 1** (y=1080–2159): Mid/Moderate — zones 5-9. Mix of safe and danger. Enemies tier 1.
- **Row 2** (y=2160–3239): Dangerous/Elite — zones 10-14. All flagged danger. Enemies tier 2.

This creates a natural "go further south or east to find harder content" progression.

### 1.5 Constants to Replace (in exploration_map.gd)

```gdscript
## OLD — DELETE these
const MAP_W   := 48000.0
const MAP_H   := 2160.0
const ZONE_W  := 3200.0
const ZONE_COUNT := 15
const LANE_UPPER  := 720.0
const LANE_CENTER := 1080.0
const LANE_LOWER  := 1440.0

## NEW — REPLACE WITH
const MAP_W      := 9600.0
const MAP_H      := 3240.0
const ZONE_W     := 1920.0
const ZONE_H     := 1080.0
const ZONE_COLS  := 5
const ZONE_ROWS  := 3
const ZONE_COUNT := 15
const ENTRY_POS  := Vector2(320.0, 540.0)  ## Zone 0, left of center — safe entry
```

### 1.6 Zone Helper Functions (add to exploration_map.gd)

```gdscript
func _zone_col(z: int) -> int:
    return z % ZONE_COLS

func _zone_row(z: int) -> int:
    return z / ZONE_COLS

func _zone_origin(z: int) -> Vector2:
    return Vector2(float(_zone_col(z)) * ZONE_W, float(_zone_row(z)) * ZONE_H)

func _zone_center(z: int) -> Vector2:
    return _zone_origin(z) + Vector2(ZONE_W * 0.5, ZONE_H * 0.5)

## Returns zone index for a world position (hero detection).
## Used in _process() to detect current zone.
func _zone_at(world_pos: Vector2) -> int:
    var col: int = clampi(int(world_pos.x / ZONE_W), 0, ZONE_COLS - 1)
    var row: int = clampi(int(world_pos.y / ZONE_H), 0, ZONE_ROWS - 1)
    return row * ZONE_COLS + col
```

### 1.7 Zone Detection Update (in _process)
Replace the 1D zone detection:
```gdscript
## OLD
var zone_idx_now: int = int(hero_pos.x / ZONE_W)

## NEW
var zone_idx_now: int = _zone_at(hero_pos)
```

---

## SECTION 2 — ZONE VISUAL IDENTITY

### 2.1 Background Layer
Each zone has a full 1920×1080 colored background rect. Adjacent zones may have slightly
different hues to reinforce the sense of entering new territory.

The `_build_background()` function must be rewritten:
```gdscript
func _build_background() -> void:
    for z: int in range(ZONE_COUNT):
        var origin: Vector2 = _zone_origin(z)
        var def: Dictionary = ZONE_DEFS[z]
        ## Main zone rect
        var r := ColorRect.new()
        r.size     = Vector2(ZONE_W, ZONE_H)
        r.position = origin
        r.color    = def.col
        r.z_index  = -20
        add_child(r)
        ## Subtle gradient overlay at the BOTTOM edge — darkens the ground
        var ground := ColorRect.new()
        ground.size     = Vector2(ZONE_W, 80.0)
        ground.position = origin + Vector2(0.0, ZONE_H - 80.0)
        ground.color    = Color(0.0, 0.0, 0.0, 0.22)
        ground.z_index  = -19
        add_child(ground)
        ## Subtle gradient overlay at the TOP edge — lighter sky
        var sky := ColorRect.new()
        sky.size     = Vector2(ZONE_W, 60.0)
        sky.position = origin
        sky.color    = Color(1.0, 1.0, 1.0, 0.08)
        sky.z_index  = -19
        add_child(sky)
        ## Zone border (right and bottom edges only — 4px dark separator)
        if _zone_col(z) < ZONE_COLS - 1:
            var div_right := ColorRect.new()
            div_right.size     = Vector2(4.0, ZONE_H)
            div_right.position = origin + Vector2(ZONE_W - 2.0, 0.0)
            div_right.color    = Color(0.0, 0.0, 0.0, 0.40)
            div_right.z_index  = -17
            add_child(div_right)
        if _zone_row(z) < ZONE_ROWS - 1:
            var div_bottom := ColorRect.new()
            div_bottom.size     = Vector2(ZONE_W, 4.0)
            div_bottom.position = origin + Vector2(0.0, ZONE_H - 2.0)
            div_bottom.color    = Color(0.0, 0.0, 0.0, 0.40)
            div_bottom.z_index  = -17
            add_child(div_bottom)
        ## Zone label — subtle, top-left of zone, alpha 0.40
        var lbl := Label.new()
        lbl.text     = def.n
        lbl.position = origin + Vector2(16.0, 12.0)
        lbl.add_theme_font_size_override("font_size", 11)
        lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.40))
        lbl.z_index  = -16
        add_child(lbl)
```

### 2.2 Remove the Paths/Lane System
Delete `_build_paths()` entirely. There are no more lanes. The hero walks freely on the
2D terrain. Decorative paths can be suggested by sparse prop placement but are NOT
implemented as solid ColorRects spanning the whole world.

### 2.3 Decoration Density Rules
For a zone that feels "full" and not empty:
- **Minimum decoration count per zone**: 40–60 sprites (trees, rocks, environment props)
- **Distribution**: Random scatter across the FULL zone area (x: 0–1920, y: 0–1080)
- **Density clusters**: Use a cluster function — place 3–5 related props within 80px of each
  other to create "copses" of trees, "rock formations", etc.
- **Margin**: 40px margin from zone edges to avoid clipping at zone borders

### 2.4 Zone Decoration Style Mapping (update `_build_zone_decorations`)
The function signature changes to:
```gdscript
func _build_zone_decorations(z: int, origin: Vector2, rng: RandomNumberGenerator, style: int) -> void:
```

Replace all `zone_x + randf(0, ZONE_W)` and `randf(80, MAP_H - 80)` with:
```gdscript
var px: float = origin.x + rng.randf_range(40.0, ZONE_W - 40.0)
var py: float = origin.y + rng.randf_range(40.0, ZONE_H - 40.0)
```

Keep all 11 decoration styles, just fix the coordinate system.

---

## SECTION 3 — RESOURCE SYSTEM

### 3.1 Philosophy
Resources should feel naturally distributed throughout the 2D zone — not in rows.
A player exploring a forest zone should find berries and herbs scattered at all depths,
not just at 3 fixed Y positions. Clusters of the same resource type feel organic.

### 3.2 Placement Algorithm — Instant Resources
Replace the lane-based placement with a 2D grid scatter:

```gdscript
func _spawn_zone_instant_resources(z: int, origin: Vector2, rng: RandomNumberGenerator, pool: Array) -> void:
    if pool.is_empty():
        return
    var node_script: GDScript = load("res://src/gameplay/resource_node.gd")
    ## Divide zone into a 5×4 cell grid (each cell ~384×270 px)
    ## Place 1–2 resources per cell with random offset within the cell
    const GRID_COLS := 5
    const GRID_ROWS := 4
    const CELL_W    := 384.0  ## ZONE_W / GRID_COLS = 1920/5
    const CELL_H    := 270.0  ## ZONE_H / GRID_ROWS = 1080/4
    const MARGIN    := 40.0   ## Keep nodes away from cell edges
    for row: int in range(GRID_ROWS):
        for col: int in range(GRID_COLS):
            ## Skip ~20% of cells to avoid uniform coverage
            if rng.randf() < 0.20:
                continue
            ## 1 node per cell always, second node only 40% of the time
            var nodes_in_cell: int = 1 + (1 if rng.randf() < 0.40 else 0)
            for _n: int in range(nodes_in_cell):
                var cell_origin_x: float = origin.x + float(col) * CELL_W
                var cell_origin_y: float = origin.y + float(row) * CELL_H
                var px: float = cell_origin_x + rng.randf_range(MARGIN, CELL_W - MARGIN)
                var py: float = cell_origin_y + rng.randf_range(MARGIN, CELL_H - MARGIN)
                var res_type: int = pool[rng.randi_range(0, pool.size() - 1)]
                var node: Area2D = Area2D.new()
                node.set_script(node_script)
                node.position = Vector2(px, py)
                add_child(node)
                node.setup(res_type)
                _interactables.append(node)
```

Expected result: ~16–24 instant resource nodes per zone (vs 8–12 previously), scattered across
the full 1920×1080 area in a pseudo-random but evenly distributed pattern.

### 3.3 Placement Algorithm — Timed Resources
Same approach for mining nodes, but sparser (2–4 per zone), placed in "hidden" spots:
away from the center, near zone edges, or in corners:

```gdscript
func _spawn_zone_timed_resources(z: int, origin: Vector2, rng: RandomNumberGenerator, pool: Array) -> void:
    if pool.is_empty():
        return
    var node_script: GDScript = load("res://src/gameplay/resource_node_timed.gd")
    var count: int = rng.randi_range(2, 4)
    ## Timed nodes favor corners and edges — harder to find
    const POSITIONS: Array[Vector2] = [
        Vector2(0.15, 0.15),   ## Top-left quadrant
        Vector2(0.85, 0.15),   ## Top-right quadrant
        Vector2(0.15, 0.85),   ## Bottom-left quadrant
        Vector2(0.85, 0.85),   ## Bottom-right quadrant
        Vector2(0.50, 0.20),   ## Top center
        Vector2(0.50, 0.80),   ## Bottom center
    ]
    ## Shuffle to pick random positions without duplicates
    var indices: Array[int] = [0, 1, 2, 3, 4, 5]
    for i in range(indices.size() - 1, 0, -1):
        var j: int = rng.randi_range(0, i)
        var tmp: int = indices[i]
        indices[i] = indices[j]
        indices[j] = tmp
    for i: int in range(mini(count, indices.size())):
        var pos_frac: Vector2 = POSITIONS[indices[i]]
        var px: float = origin.x + pos_frac.x * ZONE_W + rng.randf_range(-80.0, 80.0)
        var py: float = origin.y + pos_frac.y * ZONE_H + rng.randf_range(-60.0, 60.0)
        px = clampf(px, origin.x + 60.0, origin.x + ZONE_W - 60.0)
        py = clampf(py, origin.y + 60.0, origin.y + ZONE_H - 60.0)
        var res_type: int = pool[rng.randi_range(0, pool.size() - 1)]
        var node: Area2D = Area2D.new()
        node.set_script(node_script)
        node.position = Vector2(px, py)
        add_child(node)
        node.setup(res_type)
        _interactables.append(node)
```

### 3.4 Dynamic Event Resource Spawning
Update `_on_spawn_meteor_nodes()` and `_on_spawn_migration_drops()` to use zone origins
instead of zone X offsets and lane Y positions:

```gdscript
func _on_spawn_meteor_nodes(zone_idx: int) -> void:
    var origin: Vector2 = _zone_origin(zone_idx)
    var rng := RandomNumberGenerator.new()
    rng.seed = zone_idx * 5003 + int(Time.get_ticks_msec())
    var node_script: GDScript = load("res://src/gameplay/resource_node_timed.gd")
    for _i: int in range(3):
        var node: Area2D = Area2D.new()
        node.set_script(node_script)
        node.position = Vector2(
            origin.x + rng.randf_range(200.0, ZONE_W - 200.0),
            origin.y + rng.randf_range(200.0, ZONE_H - 200.0))
        add_child(node)
        node.setup(ResourceInventory.Type.STAR_DUST)
        _interactables.append(node)
```

---

## SECTION 4 — ENEMY CAMP SYSTEM

### 4.1 Philosophy
Enemy camps should feel like organized outposts scattered across the zone, NOT all
placed on a single horizontal axis. A camp at a zone corner feels like a genuine
"guarded area" the player must navigate around or fight through.

### 4.2 Camp Placement Algorithm
Each zone has 1–2 camps (per ZONE_CAMP_COUNT). Camps are placed at randomized
positions within the zone, away from the entry area (zone 0's west side):

```gdscript
func _spawn_zone_camps(z: int, origin: Vector2, rng: RandomNumberGenerator) -> void:
    var camp_script: GDScript = load("res://src/gameplay/rpg_enemy_camp.gd")
    var tier: int = ZONE_CAMP_TIER[z]
    var count: int = ZONE_CAMP_COUNT[z]
    ## Define forbidden area: zone 0's entry region (first 400px of zone 0)
    ## For all other zones, camps can be anywhere in the inner 80% of the zone
    const CAMP_MARGIN := 200.0
    ## For multi-camp zones, ensure camps are at least 400px apart
    var placed_positions: Array[Vector2] = []
    for _i: int in range(count):
        var attempts: int = 0
        var camp_pos: Vector2 = Vector2.ZERO
        while attempts < 20:
            camp_pos = Vector2(
                origin.x + rng.randf_range(CAMP_MARGIN, ZONE_W - CAMP_MARGIN),
                origin.y + rng.randf_range(CAMP_MARGIN, ZONE_H - CAMP_MARGIN))
            ## For zone 0: push camps away from entry (x > 400)
            if z == 0:
                camp_pos.x = maxf(camp_pos.x, origin.x + 500.0)
            ## Check minimum separation from other camps in this zone
            var too_close: bool = false
            for prev: Vector2 in placed_positions:
                if camp_pos.distance_to(prev) < 400.0:
                    too_close = true
                    break
            if not too_close:
                break
            attempts += 1
        placed_positions.append(camp_pos)
        _add_camp_marker(camp_pos, tier)
        var camp: Node = Node.new()
        camp.set_script(camp_script)
        add_child(camp)
        var camp_idx: int = _camps.size()
        camp.setup(camp_pos, _hero, self, tier)
        camp.cleared.connect(
            func(pos: Vector2, gold: int) -> void: _on_camp_cleared(camp_idx, pos, gold))
        _camps.append(camp)
```

### 4.3 Camp Difficulty by Row
Update `ZONE_CAMP_TIER`:
```gdscript
## Row 0 (safe): all tier 0
## Row 1 (mid):  zones 5-7 tier 1, zones 8-9 tier 1
## Row 2 (elite): all tier 2
const ZONE_CAMP_TIER: Array[int] = [
    0, 0, 0, 1, 1,   ## Row 0: zones 0-4 (0-1 slight escalation in cols 3-4)
    1, 1, 1, 1, 1,   ## Row 1: zones 5-9
    2, 2, 2, 2, 2,   ## Row 2: zones 10-14
]
```

### 4.4 Danger Zone Detection (2D)
Replace the 1D danger check in `_process()`:
```gdscript
## OLD (1D):
var zone_idx_now: int = int(hero_pos.x / ZONE_W)

## NEW (2D):
var zone_idx_now: int = _zone_at(hero_pos)
var in_danger: bool = ZONE_DEFS[zone_idx_now].danger
```

The danger vignette will pulse correctly as the hero crosses into row 2 or certain
col-4 zones.

### 4.5 Enemy AI (No Changes Required)
The `rpg_enemy.gd` AI is already well-implemented:
- PATROL → CHASE → ATTACK → RETURN state machine
- `direction_to()` steering (no NavMesh, ADR-006 compliant)
- Aggro radius, chase break, attack range all tuned
- Poison, slow effects working

No changes needed to `rpg_enemy.gd` or `rpg_enemy_camp.gd`.

---

## SECTION 5 — HERO MOVEMENT & WORLD BOUNDS

### 5.1 Current Movement System (Keep as-is)
The hero already moves in full 2D using the virtual joystick (8-directional). The movement
system in `hero.gd` is correct. The ONLY change needed is the world bounds constant.

### 5.2 Update hero.gd World Bounds
```gdscript
## OLD
const WORLD_MAX_EXPL := Vector2(3840.0, 1080.0)

## NEW (5 zones × 1920, 3 zones × 1080)
const WORLD_MAX_EXPL := Vector2(9600.0, 3240.0)
```

WORLD_MIN stays at `Vector2(0.0, 0.0)` — unchanged.
WORLD_MAX_TD stays at `Vector2(1920.0, 1080.0)` — unchanged.

### 5.3 Hero Entry Position (Main.gd)
In `_do_explore()`, change the hero's entry position:
```gdscript
## OLD
_hero.position = Vector2(200.0, 1080.0)

## NEW — Zone 0 center-left, comfortably inside the starting zone
_hero.position = Vector2(320.0, 540.0)
```

This places the hero at the left third of zone 0, vertically centered. The castle is at
`Vector2(200, 540)` in TD mode. Entry at (320, 540) gives a consistent "came from the west"
visual feel.

### 5.4 Movement Feel Considerations
With a 9600×3240 world and hero speed 200px/s:
- Crossing one zone (1920px) takes ~9.6 seconds at full speed — satisfying
- Crossing the full world width (9600px) takes ~48 seconds — not oppressive
- Crossing from top to bottom (3240px) takes ~16 seconds — good vertical exploration incentive

No speed changes needed. The existing HERO_SPEED = 200 is well-calibrated.

---

## SECTION 6 — CAMERA SYSTEM

### 6.1 Exploration Limits Update (camera_follow.gd)
The current code (modified in this session) has `EXPL_LIMIT_RIGHT = 3840`. This must be
updated to match the new world dimensions:

```gdscript
## Update in camera_follow.gd
const EXPL_LIMIT_RIGHT  := 9600   ## NEW — 5 zones × 1920
const EXPL_LIMIT_BOTTOM := 3240   ## ADD — 3 zones × 1080

func _on_state_changed(new_state: int) -> void:
    if _camera == null:
        return
    if new_state == GameStateMachine.State.EXPLORING:
        _camera.limit_right  = EXPL_LIMIT_RIGHT
        _camera.limit_bottom = EXPL_LIMIT_BOTTOM
    else:
        _camera.limit_right  = LIMIT_RIGHT
        _camera.limit_bottom = LIMIT_BOTTOM
```

Note: `LIMIT_BOTTOM` in the current code is 1080 (for TD world). When returning from
EXPLORING to PLAYING, this gets restored correctly.

### 6.2 Camera Snap on Explore Entry
When the hero enters EXPLORING mode, the camera should immediately snap to the hero's
position (no interpolation for the first frame). This already happens via `_on_session_reset()`
being connected to `session_reset`. For exploration entry specifically, the camera snaps
because `_hero.global_position` is set before the camera processes.

No changes needed beyond the limit update.

---

## SECTION 7 — MINI-MAP REDESIGN

### 7.1 Current State
The minimap implemented in this session is 144×44 px and shows a single dot for the hero.
With a 5×3 grid world, it needs to show the zone grid clearly.

### 7.2 Updated Minimap Layout
The minimap should show:
- 5×3 grid of tiny colored rectangles (one per zone)
- Hero dot (white/yellow, 3×3 px)
- Castle dot (gold, at entry area)
- Zone state coloring (WILD=dim, CONTESTED=mid, PACIFIED=bright, FLOURISHING=very bright)

**Minimap dimensions**: 145×54 px (wider to fit 5-wide grid better)
**Zone tile size**: `(MINIMAP_W - 10) / 5 = 27 px wide × (MINIMAP_H - 10) / 3 = 15 px tall`

### 7.3 Updated Constants in hud.gd
```gdscript
## Replace old constants
const MINIMAP_X := 812.0
const MINIMAP_Y := 6.0
const MINIMAP_W := 145.0
const MINIMAP_H := 54.0
const MINIMAP_WORLD_W := 9600.0   ## Updated from 3840
const MINIMAP_WORLD_H := 3240.0   ## Updated from 1080

## New zone tile constants
const MM_TILE_W := 26.0   ## (145 - 15) / 5 = ~26 px per zone column
const MM_TILE_H := 15.0   ## (54 - 9) / 3 = 15 px per zone row
const MM_TILE_PAD := 1.0  ## 1px gap between zone tiles
```

### 7.4 Zone Grid Build (replace current minimap code in build_rpg_elements)
Instead of just a background rect, build a 5×3 grid of zone tiles:

```gdscript
## In build_rpg_elements(), replace _minimap_bg block with:
_minimap_bg = ColorRect.new()
_minimap_bg.position = Vector2(MINIMAP_X - 3.0, MINIMAP_Y - 3.0)
_minimap_bg.size = Vector2(MINIMAP_W + 6.0, MINIMAP_H + 6.0)
_minimap_bg.color = Color(0.04, 0.04, 0.04, 0.90)
_minimap_bg.visible = false
parent.add_child(_minimap_bg)

## Build zone tiles (5×3 grid)
for z: int in range(15):
    var col: int = z % 5
    var row: int = z / 5
    var tile := ColorRect.new()
    tile.position = Vector2(
        MINIMAP_X + float(col) * (MM_TILE_W + MM_TILE_PAD),
        MINIMAP_Y + float(row) * (MM_TILE_H + MM_TILE_PAD))
    tile.size = Vector2(MM_TILE_W, MM_TILE_H)
    ## Color from ZONE_DEFS (dimmed for minimap)
    var zone_col: Color = ExplorationMapDefs.ZONE_COLORS[z]   ## see note below
    tile.color = Color(zone_col.r * 0.7, zone_col.g * 0.7, zone_col.b * 0.7, 0.90)
    tile.visible = false
    tile.name = "ZoneTile_%d" % z
    parent.add_child(tile)
    _minimap_bg.set_meta("zone_tile_%d" % z, tile)

## Hero dot — on top of zone tiles
_minimap_hero_dot = ColorRect.new()
_minimap_hero_dot.size = Vector2(4.0, 4.0)
_minimap_hero_dot.color = Color(1.0, 1.0, 1.0, 1.0)
_minimap_hero_dot.z_index = 2
_minimap_hero_dot.visible = false
parent.add_child(_minimap_hero_dot)
```

**Implementation note**: Since `hud.gd` cannot directly access `exploration_map.gd`'s
`ZONE_DEFS` (different scene), the zone colors must be passed to the HUD. The simplest approach
is to hardcode the 15 zone colors in `hud.gd` as a constant array — they never change at runtime.

### 7.5 Hero Dot Update (in _process)
The hero dot update formula must account for the new world dimensions:
```gdscript
## In _process() minimap update section:
var tile_total_w: float = (MM_TILE_W + MM_TILE_PAD) * ZONE_COLS
var tile_total_h: float = (MM_TILE_H + MM_TILE_PAD) * ZONE_ROWS
var mx: float = MINIMAP_X + clampf(hero_pos.x / MINIMAP_WORLD_W, 0.0, 1.0) * tile_total_w - 2.0
var my: float = MINIMAP_Y + clampf(hero_pos.y / MINIMAP_WORLD_H, 0.0, 1.0) * tile_total_h - 2.0
_minimap_hero_dot.position = Vector2(mx, my)
```

---

## SECTION 8 — INTERACTABLES & POINTS OF INTEREST

### 8.1 Placement Philosophy
With a 2D world, interactables must be distributed across both axes. Shrines, anvils,
and NPCs should not all be at the same Y position.

### 8.2 Healing Shrines (8 shrines, one per even-numbered zone)
Updated placement — position in zone quadrant to create exploration incentive:
```gdscript
## Shrine positioned at a quadrant center, NOT at LANE_CENTER
if z in SHRINE_ZONES:
    var origin: Vector2 = _zone_origin(z)
    ## Alternate shrine quadrant: even rows → top-center, odd rows → bottom-center
    var shrine_y_frac: float = 0.30 if (_zone_row(z) % 2 == 0) else 0.70
    var shrine_pos := Vector2(
        origin.x + ZONE_W * 0.60,
        origin.y + ZONE_H * shrine_y_frac)
    _spawn_shrine(shrine_pos)
```

### 8.3 Crafting Anvils (4 anvils in zones 2, 6, 10, 14)
Place at zone center-right to reward deeper exploration within the zone:
```gdscript
if z in ANVIL_ZONES:
    var origin: Vector2 = _zone_origin(z)
    var anvil_pos := Vector2(origin.x + ZONE_W * 0.70, origin.y + ZONE_H * 0.50)
    _spawn_anvil(anvil_pos)
```

### 8.4 Hidden Caves (8 caves)
Caves remain at random positions within zones (already random), just update to use
zone origins instead of LANE_UPPER/LOWER:
```gdscript
if z in CAVE_ZONES:
    var origin: Vector2 = _zone_origin(z)
    var cave_pos := Vector2(
        origin.x + rng.randf_range(300.0, ZONE_W - 300.0),
        origin.y + rng.randf_range(200.0, ZONE_H - 200.0))
    _spawn_cave(cave_pos, z, z * 7919 + 13)
```

### 8.5 NPC Wanderers (15 NPCs, one per zone)
Spread across zones in varied positions. NPCs wander within their zone:
```gdscript
var origin: Vector2 = _zone_origin(z)
var npc_pos := Vector2(
    origin.x + rng.randf_range(400.0, ZONE_W - 400.0),
    origin.y + rng.randf_range(200.0, ZONE_H - 200.0))
_spawn_npc(npc_pos, ZONE_NPC_TYPE[z])
```

### 8.6 Lore Tablets (15 tablets, one per zone)
Random position in zone:
```gdscript
var origin: Vector2 = _zone_origin(z)
var lore_pos := Vector2(
    origin.x + rng.randf_range(300.0, ZONE_W - 300.0),
    origin.y + rng.randf_range(150.0, ZONE_H - 150.0))
_make_lore_tablet(lore_pos, z)
```

### 8.7 Contract Boards (2 boards)
Place at meaningful positions — zone 0 (near entry) and zone 7 (map center):
```gdscript
func _build_contract_board() -> void:
    var board_script: GDScript = load("res://src/gameplay/contract_board.gd")
    ## Board 1: Zone 0, right of entry — early contract availability
    var board1_pos := Vector2(600.0, 540.0)
    var board: Area2D = Area2D.new()
    board.set_script(board_script)
    board.position = board1_pos
    add_child(board)
    board.setup(12345)
    board.contracts_panel_requested.connect(_on_contracts_panel_requested)
    board.contract_fulfilled.connect(_on_contract_fulfilled)
    _interactables.append(board)
    ## Board 2: Zone 7 center (col=2, row=1) — mid-world hub
    var zone7_origin: Vector2 = _zone_origin(7)
    var board2_pos := zone7_origin + Vector2(ZONE_W * 0.50, ZONE_H * 0.50)
    var board2: Area2D = Area2D.new()
    board2.set_script(board_script)
    board2.position = board2_pos
    add_child(board2)
    board2.setup(67890)
    board2.contracts_panel_requested.connect(_on_contracts_panel_requested)
    board2.contract_fulfilled.connect(_on_contract_fulfilled)
    _interactables.append(board2)
```

### 8.8 Return Portal
The return portal should NOT be at `MAP_W - 100` (far end of the old linear map).
It should be at zone 0, near the entry point — the player returns home the same way
they came, which is a classic RPG structure:
```gdscript
func _build_return_portal() -> void:
    ## Zone 0, just left/above entry — the "gate home"
    const PORTAL_POS := Vector2(100.0, 540.0)
    ## ... (keep existing visual code, just change CENTER to PORTAL_POS)
```

---

## SECTION 9 — ZONE BLESSING & PROGRESSION (2D Update)

### 9.1 Zone Dwell Detection (2D)
The blessing system tracks how long the hero stays in a zone. With 2D zones, the detection
must use `_zone_at()` instead of dividing by ZONE_W:

```gdscript
## In _process(), replace:
var zone_idx_now: int = int(hero_pos.x / ZONE_W)  ## OLD

## With:
var zone_idx_now: int = _zone_at(hero_pos)  ## NEW — 2D zone detection
```

Everything else in the blessing system works unchanged.

### 9.2 WorldStateManager — No Changes Needed
WorldStateManager uses zone_idx integers (0–14) and doesn't care about their spatial layout.
All `on_camp_cleared()` and `on_zone_visited()` calls work correctly.

---

## IMPLEMENTATION ORDER (for sub-agents)

Execute these in order. Each sub-agent reads this document and the specific file it modifies.

### Step 1 — Update exploration_map.gd (LARGEST CHANGE)
Rewrite the following functions completely:
- Constants block (Section 1.5)
- Add helper functions `_zone_col`, `_zone_row`, `_zone_origin`, `_zone_center`, `_zone_at` (Section 1.6)
- `_build_background()` (Section 2.1)
- Delete `_build_paths()` entirely
- `_build_zone()` — update all calls to use `origin` instead of `zone_x_start` and lanes
- `_build_zone_decorations()` — fix coordinate system (Section 2.4)
- `_spawn_zone_instant_resources()` — full replacement with 2D grid scatter (Section 3.2)
- `_spawn_zone_timed_resources()` — full replacement (Section 3.3)
- `_spawn_zone_camps()` — full replacement (Section 4.2)
- `_build_contract_board()` — replace positions (Section 8.7)
- `_build_return_portal()` — move to entry area (Section 8.8)
- `_build_zone()` — update shrine/anvil/cave/NPC/lore positions (Sections 8.2-8.6)
- `_process()` — update zone detection to 2D (Section 4.4 / 9.1)
- `_on_spawn_meteor_nodes()` — fix to use zone origin (Section 3.4)
- `_on_spawn_ambush()` — verify it uses world_pos directly (no change)

### Step 2 — Update hero.gd
- Change `WORLD_MAX_EXPL` from `Vector2(3840.0, 1080.0)` to `Vector2(9600.0, 3240.0)` (Section 5.2)

### Step 3 — Update camera_follow.gd
- Change `EXPL_LIMIT_RIGHT` from 3840 to 9600 (Section 6.1)
- Add `EXPL_LIMIT_BOTTOM := 3240`
- Update `_on_state_changed()` to also set `_camera.limit_bottom = EXPL_LIMIT_BOTTOM` when EXPLORING

### Step 4 — Update Main.gd hero entry position
- Change hero position in `_do_explore()` from `Vector2(200.0, 1080.0)` to `Vector2(320.0, 540.0)` (Section 5.3)

### Step 5 — Update hud.gd minimap
- Change `MINIMAP_WORLD_W` from 3840 to 9600
- Change `MINIMAP_WORLD_H` from 1080 to 3240
- Add `MINIMAP_ZONE_COLS := 5` and `MINIMAP_ZONE_ROWS := 3`
- Update hero dot position formula to use actual zone grid tile dimensions (Section 7.5)
- Update MINIMAP_H to 54 for better zone grid visibility (Section 7.2)
- Add zone tile constants MM_TILE_W, MM_TILE_H, MM_TILE_PAD (Section 7.3)

---

## QUALITY CHECKLIST (before shipping)

After all steps are implemented, verify:
- [ ] Hero spawns at Vector2(320, 540) in EXPLORING mode, camera snaps there immediately
- [ ] Hero can freely move in all 4 directions, reaches all 15 zones
- [ ] Camera follows hero with lerp, stops at world edges (0,0)-(9600,3240)
- [ ] Zone backgrounds are full 1920×1080 colored rects, not horizontal bands
- [ ] Resources visible across the full zone area (not just 3 Y positions)
- [ ] Enemy camps have 2D varied positions (not all at center-Y)
- [ ] Healing shrine appears in every even zone, not at a fixed lane position
- [ ] Return portal is near entry (x<200), not at far end of map
- [ ] Mini-map shows correct hero dot moving in 2D space
- [ ] Danger vignette pulses in row 1/2 zones when hero is in danger zones
- [ ] Zone blessing triggers correctly after 30s dwell in any zone
- [ ] WorldStateManager zone states persist across explorations
