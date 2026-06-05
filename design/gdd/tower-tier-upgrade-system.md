# Tower Tier Upgrade System — Garrison GDD

**Status**: Draft
**Author**: Research + Design pass, 2026-05-25
**Dependencies**: archer_tower.gd, economy.gd, forge.gd, Main.gd, gen_sprites.py
**Viewport**: 960x540 landscape, world 1920x1080 (ADR-001)

---

## 1. Overview

Towers currently exist as a single permanent tier purchased for 100g with an optional
150g power upgrade (FIRE/LIGHTNING/WATER). This system adds three visual and mechanical
tiers to each tower: Tier 1 Wood (base), Tier 2 Stone (reinforced), Tier 3 Iron (elite).
Each tier increases the tower's range, damage output, and fire rate, and changes the
sprite to reflect the material upgrade. The three existing power types carry over to any
tier — they are orthogonal to the tier system. Towers cannot be downgraded.

---

## 2. Player Fantasy

The player watches a rough wooden watchtower transform into a forbidding iron fortress
as they invest gold. Each upgrade is a visible commitment: the tower literally looks
stronger. A Tier 3 tower with FIRE power should feel like an anchor point that holds
a lane by itself. The progression creates a meaningful sink for gold between waves and
gives a goal for the late-game economy.

---

## 3. Detailed Rules

1. Each tower starts at Tier 1 (Wood) when purchased for the existing 100g.
2. A tower can be upgraded to Tier 2 (Stone) for 200g, and then to Tier 3 (Iron) for 350g.
3. Upgrade is triggered by tapping the tower, which opens the existing power panel — the
   panel will be extended to show an UPGRADE button alongside the three power buttons.
4. Upgrade costs are deducted immediately from economy.current_gold via economy.spend_gold().
5. A tower's TowerPower (NONE/FIRE/LIGHTNING/WATER) is preserved through tier upgrades.
6. A tower's tier is permanent for the session (no downgrade, no refund).
7. The sprite is swapped in-place; the tower node is not re-instantiated.
8. Upkeep per tower scales with tier: 8g/wave (T1) -> 12g/wave (T2) -> 18g/wave (T3).
9. Max 5 towers on the map regardless of tier.
10. Tier is NOT reset on session_reset — towers are permanent per the existing ADR-007 note
    ("Towers are PERMANENT — they do NOT reset on session_reset.").

---

## 4. Formulas

All values relative to Tier 1 baseline. Forge multipliers stack on top of tier multipliers.

### Stat table

| Stat              | Tier 1 (Wood) | Tier 2 (Stone) | Tier 3 (Iron) |
|-------------------|---------------|----------------|---------------|
| Range (px)        | 350           | 420            | 510           |
| Base damage       | forge F1 base | F1 base x 1.30 | F1 base x 1.65 |
| Shoot interval    | forge F2 base | F2 base x 0.82 | F2 base x 0.65 |
| Archers on top    | 2             | 2              | 3             |
| Upkeep/wave (g)   | 8             | 12             | 18            |
| Upgrade cost (g)  | n/a (purchase)| 200            | 350           |

### Range formula
```
effective_range(tier) = TOWER_RANGE_BASE + (tier - 1) * TOWER_RANGE_STEP
  where TOWER_RANGE_BASE = 350, TOWER_RANGE_STEP = 80
```

### Damage formula (combines tier and Forge)
```
effective_damage(tier, forge) = round(forge.effective_proj_damage() * TIER_DMG_MULT[tier])
  TIER_DMG_MULT = {1: 1.00, 2: 1.30, 3: 1.65}
```

### Fire interval formula (combines tier and Forge)
```
effective_ivtl(tier, forge) = forge.effective_shoot_ivtl() * TIER_IVTL_MULT[tier]
  TIER_IVTL_MULT = {1: 1.00, 2: 0.82, 3: 0.65}
  Result is always >= SHOOT_IVTL_FLOOR (0.40s) as defined in forge.gd
```

### Upgrade cost lookup
```
TIER_UPGRADE_COST = {2: 200, 3: 350}
```

---

## 5. Edge Cases

- Player taps a Tier 3 tower: panel shows no UPGRADE button (already max tier).
- Player taps a tower while gold is insufficient for upgrade: UPGRADE button is shown
  but disabled (greyed out), text shows cost so player understands what is needed.
- session_reset fires while towers are T2/T3: towers remain at their current tier.
  This is consistent with the existing permanent-tower contract.
- FIRE/LIGHTNING power interaction with Tier 3 speed bonus: both multipliers apply.
  Lightning divides the already-reduced Tier 3 interval by LIGHTNING_SPD_MULT (1.80),
  subject to the 0.40s floor in forge.gd.
- Tier 3 archers (3 on platform): the _ready() loop in archer_tower.gd currently
  spawns exactly 2 archer sprites. An _upgrade_visual() method will add the third
  archer sprite when upgrading to Tier 3.
- Upkeep on mixed-tier armies: Economy._on_wave_cleared() must query each tower's
  individual tier upkeep, not use a fixed constant. Economy._tower_count is replaced
  by a list reference that allows per-tower upkeep queries.

---

## 6. Dependencies

- `src/gameplay/archer_tower.gd` — TowerTier enum, stat multipliers, visual swap,
  upgrade signal, archer count adjustment
- `src/gameplay/economy.gd` — try_upgrade_tower(), per-tower upkeep query, TOWER_UPGRADE_COST
- `src/Main.gd` — _apply_tower_upgrade(), HUD panel extension call, tower list type change
- `src/ui/hud.gd` — show_power_panel() extended to include UPGRADE button + cost display
- `tools/gen_sprites.py` — three new functions: gen_tower_t1(), gen_tower_t2(), gen_tower_t3()
- `assets/sprites/garrison/` — archer_tower_t1.png, archer_tower_t2.png, archer_tower_t3.png

---

## 7. Tuning Knobs

All constants defined in archer_tower.gd as named consts (UPPER_SNAKE_CASE):

```
TOWER_RANGE_BASE     = 350.0     # px, Tier 1 range (existing TOWER_RANGE)
TOWER_RANGE_STEP     = 80.0      # px added per tier above T1
TIER_DMG_MULT        = {1:1.00, 2:1.30, 3:1.65}
TIER_IVTL_MULT       = {1:1.00, 2:0.82, 3:0.65}
TIER_UPGRADE_COST    = {2:200,  3:350}
TIER_UPKEEP          = {1:8,    2:12,   3:18}
TIER_ARCHER_COUNT    = {1:2,    2:2,    3:3}
```

---

## 8. Acceptance Criteria

- AC-TT-01: A Tier 1 tower fires with TOWER_RANGE=350 and damage/ivtl matching existing
  Forge-only values (no regression).
- AC-TT-02: Spending 200g on a T1 tower replaces its sprite with archer_tower_t2.png and
  immediately applies T2 range (420px) and stat multipliers.
- AC-TT-03: Spending 350g on a T2 tower replaces its sprite with archer_tower_t3.png, adds
  a third archer sprite, and applies T3 range (510px) and stat multipliers.
- AC-TT-04: A tower with FIRE power at any tier retains its FIRE effect after upgrading.
- AC-TT-05: Wave-end upkeep for a single T2 tower is 12g, T3 tower is 18g.
- AC-TT-06: The UPGRADE button is absent from the panel for a Tier 3 tower.
- AC-TT-07: Attempting to upgrade with insufficient gold does not deduct gold or change tier.
- AC-TT-08: Tier 3 towers have 3 archer sprites visible on the platform, T1 and T2 have 2.

---

---

# Visual Tier Design

## Reference research summary

Kingdom Rush Archer Tower progression (4 tiers in KR): wooden platform -> stone tower
with battlements -> stone tower with iron reinforcement and flag -> full fortress keep.
Key visual language: material escalation (wood -> stone -> metal), silhouette grows
taller and wider, decorative elements added (flags, torches, iron banding).

Bloons TD 6 design principle: each upgrade tier adds one prominent new visual element
rather than redrawing everything. Players learn to read the elements, not memorize colors.

Derived design rule for Garrison: each tier adds one unmistakable structural element on
top of the previous tier's geometry. Colors shift from warm browns (wood) to cool greys
(stone) to dark blue-grey with amber highlights (iron).

---

## Tier 1 — Wood Tower

**Philosophy**: Quick construction, improvised. A garrison outpost, not a fortress.

**Sprite size**: 100x165 px RGBA (identical to current archer_tower.png)

**Material**: Rough-hewn timber planks with visible grain lines and knot holes.

**Color palette**:
```
WD_L  = (175, 138,  92)   # plank highlight — #AF8A5C
WD_M  = (145, 110,  68)   # plank mid      — #916E44
WD_D  = (108,  80,  48)   # plank shadow   — #6C5030
WD_X  = ( 75,  54,  30)   # deep shadow    — #4B361E
WD_B  = (162, 128,  82)   # battlement top — #A28052
WD_BK = ( 58,  42,  22)   # dark timber outline — #3A2A16
```

**Structure description** (bottom to top, 3/4 perspective):
1. **Base/Foundation** (y: 153-165px): Two stone footings, slightly wider than the shaft.
   Dark grey rectangles (CS_D) suggesting a rough rock foundation. Height: 12px.
2. **Tower shaft** (y: 30-153px): Upright wooden planks — a tall box with the left
   third lit (WD_L), center two-thirds mid-tone (WD_M), right edge in shadow (WD_D).
   Horizontal plank lines every 18px, vertical grain lines every 14px. Width: 68px.
   Top face shown in 3/4 perspective using dark WD_X to imply depth.
3. **Arrow slits** (3 total, centered): Narrow vertical slots (5x16px) with arched top.
   Cut into the plank face at y: 55, 90, 118 from top of shaft.
4. **Battlements/crenellations** (y: 22-30px): 5 alternating merlons and gaps. Merlons
   are 9px wide x 18px tall, gap is 4px. Material matches WD_B (slightly lighter top).
   Top walkway is a 2px horizontal bar in WD_B.
5. **Archer area**: Two archer sprites placed at (-22, -52) and (+22, -52) relative to
   tower center, identical to current code.
6. **Distinguishing detail**: A diagonal wooden brace (WD_D line, 3px wide) on the front
   face from bottom-left to upper-right, suggesting structural reinforcement.

---

## Tier 2 — Stone Tower

**Philosophy**: Professional fortification. Quarried stone, proper battlements,
a more imposing silhouette. The improvement is immediately legible.

**Sprite size**: 100x165 px RGBA (same canvas, but shaft appears slightly wider/taller
through visual density — battlement detail is thicker)

**Material**: Cut stone blocks with mortar lines. Colder, heavier appearance.

**Color palette**:
```
ST_L  = (188, 184, 178)   # stone highlight — #BCB8B2  (existing TW_L)
ST_M  = (155, 150, 144)   # stone mid       — #9B9690  (existing TW_M)
ST_D  = (112, 110, 120)   # stone shadow    — #706E78  (existing TW_D)
ST_B  = (130, 128, 138)   # battlement top  — #82808A  (existing TW_B)
ST_X  = ( 82,  78,  74)   # deep shadow     — #524E4A  (existing CS_X)
ST_AC = (168, 148, 112)   # accent — sandstone trim  — #A89470
```

**Structure description** (changes vs T1):
1. **Base/Foundation** (y: 153-165px): Wider two-step plinth in CS_D / CS_X. Steps
   at y=153 (4px wider each side) and y=158 (8px wider), creating a proper foundation.
2. **Tower shaft** (y: 25-153px): Stone block courses. Left lit column (ST_L, 18px wide),
   center face (ST_M). Horizontal mortar lines every 22px, offset vertical joints every
   14px (alternating rows stagger by 7px, proper ashlar pattern). Shaft width: 70px.
3. **Corner quoins**: Slightly lighter 8px wide strip at top-left and bottom-left corners
   in ST_AC (sandstone accent) — suggests dressed corner stones.
4. **Arrow slits**: Wider and taller than T1 (6x20px), two visible at y: 60 and 105.
   Embrasure splays: small lighter triangles on either side of the slit (ST_M pixels)
   to suggest the angled interior.
5. **Battlements**: Thicker merlons (10px wide x 22px tall, gap 5px). Stone face shows
   one horizontal joint line mid-merlon. Merlon tops are flat stone (ST_B walkway 3px).
6. **Flag bracket**: A small iron bracket (ST_X, 4px wide x 6px tall) on the right
   battlement merlon, with a 1px flag pole (CS_X line, 14px tall) and a small red
   triangle pennant (C_FLG, 8x6px) — visible signal of occupied tower.
7. **Two archers on platform** (same positions as T1).
8. **Distinguishing detail**: The entire silhouette reads as heavier — thicker walls,
   thicker battlements, no diagonal brace (removed), replaced by a proper machicolation
   lip (3px overhang at battlement base in ST_X).

---

## Tier 3 — Iron Tower

**Philosophy**: War machine. Metal-reinforced stone, battle-worn iron plating on the
exposed faces, glowing embers in a fire basin at the top. This is a permanent fixture
that has seen many sieges.

**Sprite size**: 100x165 px RGBA (same canvas)

**Material**: Stone core with riveted iron plating on the front face. Warm amber/ember
glow at the top to indicate an always-burning watch fire.

**Color palette**:
```
IR_L  = (128, 130, 148)   # iron highlight  — #808294
IR_M  = ( 95,  96, 112)   # iron mid        — #5F6070
IR_D  = ( 62,  64,  78)   # iron shadow     — #3E404E
IR_X  = ( 38,  40,  52)   # iron deep       — #262834
IR_RV = (178, 158, 110)   # rivet gold      — #B29E6E
EM_O  = (248, 158,  50)   # ember orange    — #FF9E32  (existing FF_O)
EM_Y  = (255, 222,  98)   # ember bright    — #FFDE62  (existing FF_Y)
EM_D  = (200,  92,  28)   # ember deep      — #C85C1C  (existing FF_D)
```

**Structure description** (changes vs T2):
1. **Base/Foundation** (y: 153-165px): Three-step plinth, same as T2 but with iron
   banding strips (IR_D rectangles, 2px tall) at the base of each step.
2. **Tower shaft** (y: 25-153px): Stone base (ST_M) overlaid with iron plate panels.
   Front face divided into three vertical panel sections (each ~22px wide) by IR_X
   divider strips (2px). Each panel has 6 rivets arranged in a 2x3 grid — small circles
   (IR_RV, radius 2px) at regular intervals. Panel faces are IR_M. Lit left column: IR_L.
   Shaft width: 72px.
3. **Arrow slits**: Framed in iron (IR_X 2px border around each slit). Same dimensions
   as T2 (6x20px). Slit interior is CS_X.
4. **Battlements**: Stone merlons reinforced with iron cap-plates on top (IR_D rectangle,
   full merlon width x 4px) — the "iron crown" look. Merlon width 10px, height 24px.
   Cap plates catch the light: their top edge is IR_L (1px highlight).
5. **Watch fire basin** (at battlement walkway level, center, y: 20-28px):
   A small iron bowl (IR_D half-ellipse, 14px wide x 6px tall) sits centered on the
   walkway. Above it: flickering fire drawn as overlapping triangles:
   - Deep base:   EM_D polygon, 12px wide x 10px tall
   - Mid flame:   EM_O polygon, 8px wide x 14px tall
   - Bright tip:  EM_Y polygon, 4px wide x 18px tall
   The fire extends 18px above the battlement line, making the T3 tower the tallest-
   looking of the three even though the canvas size is the same.
6. **Three archers on platform**: Third archer added at (0, -52) center, between the
   two existing lateral positions at (-22, -52) and (+22, -52). The lateral pair
   shift slightly to (-26, -52) and (+26, -52) to accommodate the center archer.
7. **Distinguishing detail**: Iron chain anchor rings (IR_X ellipses, 5x3px) at the
   four corners of the base — visual language of "this tower is going nowhere." Two
   small chain links (IR_D line segments, 4px each) hang below each ring.

---

---

# Procedural Sprite Generation — PIL Code

## Integration with existing gen_sprites.py

The three functions below follow the exact conventions of the existing gen_sprites.py:
- Supersampling factor S=3 (global)
- px() helper converts logical pixels to supersampled pixels
- rect(), ell(), trap(), tri() helpers are already defined
- add_outline() and save_sprite() are reused as-is
- Output path uses the global OUT constant

Add the following palette entries to the PALETTE section of gen_sprites.py:

```python
# Tower Tier 1 — Wood
WD_L  = (175, 138,  92)
WD_M  = (145, 110,  68)
WD_D  = (108,  80,  48)
WD_X  = ( 75,  54,  30)
WD_B  = (162, 128,  82)

# Tower Tier 2 — Stone (most already exist as TW_* — add accent)
ST_AC = (168, 148, 112)

# Tower Tier 3 — Iron
IR_L  = (128, 130, 148)
IR_M  = ( 95,  96, 112)
IR_D  = ( 62,  64,  78)
IR_X  = ( 38,  40,  52)
IR_RV = (178, 158, 110)
```

---

## gen_tower_t1() — Wood Tower (replaces current gen_tower())

```python
def gen_tower_t1():
    """Archer Tower Tier 1 — Wood: 100x165px, rough timber construction."""
    W, H = 100*S, 165*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx = W // 2

    tw = px(68); th = px(123)
    tx1 = cx - tw//2; tx2 = cx + tw//2
    ty_top = px(30); ty_bot = ty_top + th

    # Top face of shaft (3/4 perspective)
    top_h = px(14)
    d.polygon([(tx1, ty_top), (tx2, ty_top),
               (tx2+top_h, ty_top-top_h), (tx1+top_h, ty_top-top_h)],
              fill=WD_X)
    # Right side (shadow face)
    d.polygon([(tx2, ty_top), (tx2+top_h, ty_top-top_h),
               (tx2+top_h, ty_bot-top_h), (tx2, ty_bot)], fill=WD_D)

    # Front face — mid tone
    rect(d, tx1, ty_top, tx2, ty_bot, WD_M)
    # Lit column (left third)
    rect(d, tx1, ty_top, tx1+px(18), ty_bot, WD_L)

    # Horizontal plank lines
    for sy in range(ty_top+px(18), ty_bot, px(18)):
        d.line([(tx1+px(2), sy), (tx2-px(2), sy)], fill=WD_X, width=px(1))
    # Vertical grain lines (two columns)
    for sx in range(tx1+px(8), tx1+px(18), px(6)):
        d.line([(sx, ty_top), (sx, ty_bot)], fill=WD_X, width=px(1))
    for sx in range(tx1+px(24), tx2-px(2), px(14)):
        d.line([(sx, ty_top), (sx, ty_bot)], fill=WD_X, width=px(1))

    # Diagonal brace — bottom-left to upper-right
    d.line([(tx1+px(4), ty_bot-px(8)), (tx2-px(8), ty_top+px(30))],
           fill=WD_D, width=px(3))

    # Arrow slits (3)
    for wy in [ty_top+px(30), ty_top+px(68), ty_top+px(100)]:
        sw = px(5); sh = px(16)
        rect(d, cx-sw, wy, cx+sw, wy+sh, WD_X)
        ell(d, cx, wy, sw, px(4), WD_X)

    # Battlement walkway
    btl_y = ty_top - px(4)
    rect(d, tx1-px(4), btl_y-px(2), tx2+px(4), btl_y+px(2), WD_B)
    # Merlons (5 merlons, alternating)
    merlon_w = px(9); gap_w = px(4); merlon_h = px(18)
    bx = tx1 + px(4)
    while bx + merlon_w <= tx2 - px(4):
        rect(d, bx, btl_y-merlon_h, bx+merlon_w, btl_y, WD_L)
        # Knot detail on merlon
        ell(d, bx+merlon_w//2, btl_y-merlon_h+px(5), px(3), px(2), WD_D)
        bx += merlon_w + gap_w

    # Base / foundation (stone footings)
    rect(d, tx1-px(5), ty_bot-px(10), tx2+px(5), ty_bot+px(2), CS_D)
    rect(d, tx1-px(8), ty_bot-px(4), tx2+px(8), ty_bot+px(8), CS_X)

    return img
```

---

## gen_tower_t2() — Stone Tower

```python
def gen_tower_t2():
    """Archer Tower Tier 2 — Stone: 100x165px, ashlar block construction with flag."""
    W, H = 100*S, 165*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx = W // 2

    tw = px(70); th = px(128)
    tx1 = cx - tw//2; tx2 = cx + tw//2
    ty_top = px(25); ty_bot = ty_top + th

    # Top face (3/4 perspective)
    top_h = px(16)
    d.polygon([(tx1, ty_top), (tx2, ty_top),
               (tx2+top_h, ty_top-top_h), (tx1+top_h, ty_top-top_h)],
              fill=ST_D)
    # Right side face
    d.polygon([(tx2, ty_top), (tx2+top_h, ty_top-top_h),
               (tx2+top_h, ty_bot-top_h), (tx2, ty_bot)], fill=ST_D)

    # Front face
    rect(d, tx1, ty_top, tx2, ty_bot, ST_M)
    # Lit column (left)
    rect(d, tx1, ty_top, tx1+px(18), ty_bot, TW_L)

    # Ashlar mortar lines — horizontal (every 22px, rows stagger)
    row = 0
    for sy in range(ty_top+px(22), ty_bot, px(22)):
        d.line([(tx1+px(1), sy), (tx2-px(1), sy)], fill=ST_X, width=px(1))
        # Staggered vertical joints for each row
        offset = 0 if row % 2 == 0 else px(7)
        for sx in range(tx1+px(8)+offset, tx2-px(2), px(14)):
            d.line([(sx, sy-px(22)), (sx, sy)], fill=ST_X, width=px(1))
        row += 1

    # Corner quoins (sandstone accent on left corners)
    rect(d, tx1, ty_top, tx1+px(8), ty_bot, ST_AC)

    # Machicolation lip (overhang at battlement base)
    rect(d, tx1-px(3), ty_top-px(4), tx2+px(3), ty_top+px(1), ST_X)

    # Arrow slits (2, wider with embrasure)
    for wy in [ty_top+px(38), ty_top+px(88)]:
        sw = px(6); sh = px(20)
        rect(d, cx-sw, wy, cx+sw, wy+sh, CS_X)
        ell(d, cx, wy, sw, px(5), CS_X)
        # Embrasure splay (angled sides hint)
        d.polygon([(cx-sw-px(3), wy+sh), (cx-sw, wy), (cx-sw, wy+sh)], fill=ST_M)
        d.polygon([(cx+sw+px(3), wy+sh), (cx+sw, wy), (cx+sw, wy+sh)], fill=ST_M)

    # Battlement walkway
    btl_y = ty_top - px(5)
    rect(d, tx1-px(5), btl_y-px(3), tx2+px(5), btl_y+px(2), TW_B)

    # Merlons (thicker, with stone joint)
    merlon_w = px(10); gap_w = px(5); merlon_h = px(22)
    bx = tx1 + px(3)
    while bx + merlon_w <= tx2 - px(3):
        rect(d, bx, btl_y-merlon_h, bx+merlon_w, btl_y, TW_L)
        # Mid-merlon joint
        d.line([(bx+px(1), btl_y-merlon_h//2), (bx+merlon_w-px(1), btl_y-merlon_h//2)],
               fill=ST_X, width=px(1))
        bx += merlon_w + gap_w

    # Flag bracket + pole + pennant (right battlement)
    fb_x = tx2 - px(12); fb_y = btl_y - merlon_h
    rect(d, fb_x, fb_y-px(6), fb_x+px(4), fb_y, CS_X)       # bracket
    d.line([(fb_x+px(2), fb_y-px(6)), (fb_x+px(2), fb_y-px(20))],
           fill=CS_X, width=px(1))                             # pole
    d.polygon([                                                # pennant
        (fb_x+px(2), fb_y-px(20)),
        (fb_x+px(10), fb_y-px(16)),
        (fb_x+px(2), fb_y-px(12)),
    ], fill=C_FLG)

    # Base plinth (two steps)
    rect(d, tx1-px(5), ty_bot-px(10), tx2+px(5), ty_bot+px(2), CS_D)
    rect(d, tx1-px(9), ty_bot-px(4), tx2+px(9), ty_bot+px(8), CS_X)

    return img
```

---

## gen_tower_t3() — Iron Tower

```python
def gen_tower_t3():
    """Archer Tower Tier 3 — Iron: 100x165px, stone core with riveted iron plating
    and watch fire at the top."""
    W, H = 100*S, 165*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx = W // 2

    tw = px(72); th = px(128)
    tx1 = cx - tw//2; tx2 = cx + tw//2
    ty_top = px(25); ty_bot = ty_top + th

    # Top face (3/4 perspective)
    top_h = px(16)
    d.polygon([(tx1, ty_top), (tx2, ty_top),
               (tx2+top_h, ty_top-top_h), (tx1+top_h, ty_top-top_h)],
              fill=IR_X)
    # Right side face
    d.polygon([(tx2, ty_top), (tx2+top_h, ty_top-top_h),
               (tx2+top_h, ty_bot-top_h), (tx2, ty_bot)], fill=IR_D)

    # Stone base of front face
    rect(d, tx1, ty_top, tx2, ty_bot, ST_M)

    # Iron plate panels (3 vertical panels across the front)
    panel_w = (tx2 - tx1) // 3
    for pi in range(3):
        px1 = tx1 + pi * panel_w + px(2)
        px2 = tx1 + (pi+1) * panel_w - px(2)
        # Panel face
        rect(d, px1, ty_top+px(2), px2, ty_bot-px(2), IR_M)
        # Lit left edge of each panel
        rect(d, px1, ty_top+px(2), px1+px(3), ty_bot-px(2), IR_L)
        # Divider strip between panels
        if pi < 2:
            rect(d, tx1 + (pi+1)*panel_w - px(2), ty_top, tx1 + (pi+1)*panel_w + px(2), ty_bot, IR_X)
        # Rivets: 2 columns x 3 rows per panel
        rv_cols = [px1 + px(5), px2 - px(5)]
        rv_rows = [ty_top+px(20), ty_top+px(65), ty_top+px(108)]
        for rvx in rv_cols:
            for rvy in rv_rows:
                ell(d, rvx, rvy, px(2), px(2), IR_RV)

    # Lit left column over panels
    rect(d, tx1, ty_top, tx1+px(10), ty_bot, IR_L)

    # Arrow slits — iron-framed (2 slits)
    for wy in [ty_top+px(38), ty_top+px(88)]:
        sw = px(6); sh = px(20)
        # Iron frame border
        rect(d, cx-sw-px(2), wy-px(2), cx+sw+px(2), wy+sh+px(2), IR_X)
        # Slit interior
        rect(d, cx-sw, wy, cx+sw, wy+sh, CS_X)
        ell(d, cx, wy, sw, px(5), CS_X)

    # Iron banding strips (horizontal, 3 bands)
    for by in [ty_top+px(42), ty_top+px(84), ty_top+px(120)]:
        rect(d, tx1, by, tx2, by+px(3), IR_D)
        # Rivet dot at each band end
        ell(d, tx1+px(4), by+px(1), px(2), px(2), IR_RV)
        ell(d, tx2-px(4), by+px(1), px(2), px(2), IR_RV)

    # Iron-capped battlements
    btl_y = ty_top - px(5)
    rect(d, tx1-px(5), btl_y-px(3), tx2+px(5), btl_y+px(2), IR_D)

    merlon_w = px(10); gap_w = px(5); merlon_h = px(24)
    bx = tx1 + px(3)
    while bx + merlon_w <= tx2 - px(3):
        # Stone merlon body
        rect(d, bx, btl_y-merlon_h, bx+merlon_w, btl_y, TW_L)
        # Iron cap plate on top of merlon
        rect(d, bx-px(1), btl_y-merlon_h-px(4), bx+merlon_w+px(1), btl_y-merlon_h, IR_D)
        # Cap highlight (top edge)
        d.line([(bx-px(1), btl_y-merlon_h-px(4)),
                (bx+merlon_w+px(1), btl_y-merlon_h-px(4))], fill=IR_L, width=px(1))
        bx += merlon_w + gap_w

    # Watch fire basin (centered on battlement walkway)
    basin_cx = cx; basin_y = btl_y - px(3)
    ell(d, basin_cx, basin_y, px(7), px(4), IR_D)          # iron bowl
    # Fire layers (overlapping triangles, drawn back to front)
    fire_base_y = basin_y - px(2)
    # Deep base flame
    d.polygon([
        (basin_cx-px(6), fire_base_y),
        (basin_cx+px(6), fire_base_y),
        (basin_cx, fire_base_y-px(10)),
    ], fill=EM_D)
    # Mid orange flame
    d.polygon([
        (basin_cx-px(4), fire_base_y),
        (basin_cx+px(4), fire_base_y),
        (basin_cx, fire_base_y-px(14)),
    ], fill=EM_O)
    # Bright yellow tip
    d.polygon([
        (basin_cx-px(2), fire_base_y-px(2)),
        (basin_cx+px(2), fire_base_y-px(2)),
        (basin_cx, fire_base_y-px(18)),
    ], fill=EM_Y)

    # Chain anchor rings at base corners
    anchor_positions = [
        (tx1-px(3), ty_bot-px(4)),
        (tx2+px(3), ty_bot-px(4)),
    ]
    for ax, ay in anchor_positions:
        ell(d, ax, ay, px(5), px(3), IR_X)            # outer ring
        ell(d, ax, ay, px(3), px(2), IR_D)            # inner gap (not T — dark iron)
        # Two chain links hanging below
        d.line([(ax, ay+px(3)), (ax, ay+px(8))], fill=IR_D, width=px(2))
        ell(d, ax, ay+px(10), px(3), px(2), IR_X)

    # Base plinth — three steps with iron banding
    for step, (ext, y_off) in enumerate([(5, -10), (8, -4), (11, 2)]):
        rect(d, tx1-px(ext), ty_bot+px(y_off), tx2+px(ext), ty_bot+px(y_off+6), CS_D if step < 2 else CS_X)
        # Iron band at each step
        d.line([(tx1-px(ext), ty_bot+px(y_off)), (tx2+px(ext), ty_bot+px(y_off))],
               fill=IR_D, width=px(2))

    return img
```

---

## Save calls to add to the main block

In the `if __name__ == "__main__":` block (or equivalent save section), add:

```python
save_sprite(gen_tower_t1(), "archer_tower_t1.png", 100, 165)
save_sprite(gen_tower_t2(), "archer_tower_t2.png", 100, 165)
save_sprite(gen_tower_t3(), "archer_tower_t3.png", 100, 165)
```

The existing `save_sprite(gen_tower(), "archer_tower.png", 100, 165)` line can be
replaced by the T1 save call, OR kept as an alias so the original sprite path still works
during the transition period:

```python
# Backward-compat alias — archer_tower.png remains available as Tier 1 sprite
save_sprite(gen_tower_t1(), "archer_tower.png",    100, 165)
save_sprite(gen_tower_t1(), "archer_tower_t1.png", 100, 165)
save_sprite(gen_tower_t2(), "archer_tower_t2.png", 100, 165)
save_sprite(gen_tower_t3(), "archer_tower_t3.png", 100, 165)
```

---

---

# GDScript Data Structures and Integration

## archer_tower.gd — additions

```gdscript
## Tower tier — determines visual, range, damage multiplier, fire rate multiplier.
## Permanent for the session; upgrades are irreversible.
enum TowerTier {
    WOOD  = 1,   ## Tier 1 — base purchase (100g)
    STONE = 2,   ## Tier 2 — upgrade 200g
    IRON  = 3,   ## Tier 3 — upgrade 350g
}

## Tier stat multipliers — keyed by TowerTier int value.
## Applied on top of Forge F1/F2 formulas.
const TIER_DMG_MULT: Dictionary  = {1: 1.00, 2: 1.30, 3: 1.65}
const TIER_IVTL_MULT: Dictionary = {1: 1.00, 2: 0.82, 3: 0.65}

## Range per tier (px)
const TOWER_RANGE_BASE := 350.0
const TOWER_RANGE_STEP :=  80.0

## Upgrade costs (gold) for moving to that tier
const TIER_UPGRADE_COST: Dictionary = {2: 200, 3: 350}

## Upkeep per wave per tier (gold)
const TIER_UPKEEP: Dictionary = {1: 8, 2: 12, 3: 18}

## Archer count per tier
const TIER_ARCHER_COUNT: Dictionary = {1: 2, 2: 2, 3: 3}

## Emitted when this tower's tier changes. Main wires this to update economy upkeep.
signal tier_upgraded(tower: Node2D, new_tier: int)

## Current tier — starts at WOOD on placement.
var _tier: TowerTier = TowerTier.WOOD

## Sprite references kept for in-place swap on upgrade.
var _tower_sprite: Sprite2D = null
var _archer_sprites: Array[Sprite2D] = []

## Effective range for this tower's current tier.
func effective_range() -> float:
    return TOWER_RANGE_BASE + (float(_tier) - 1.0) * TOWER_RANGE_STEP

## Effective damage per arrow, combining tier multiplier and Forge F1.
func effective_damage() -> int:
    var base: int = _forge.effective_proj_damage() if (_forge != null and _forge.has_method("effective_proj_damage")) else 8
    return roundi(float(base) * TIER_DMG_MULT[int(_tier)])

## Effective shoot interval, combining tier multiplier and Forge F2.
func effective_ivtl() -> float:
    var base: float = _forge.effective_shoot_ivtl() if _forge != null else TOWER_SHOOT_IVTL
    var ivtl: float = base * TIER_IVTL_MULT[int(_tier)]
    ## Apply Lightning power reduction on top of tier reduction
    if _power == TowerPower.LIGHTNING:
        ivtl /= LIGHTNING_SPD_MULT
    ## Floor is always enforced (from forge.gd SHOOT_IVTL_FLOOR = 0.40)
    return maxf(0.40, ivtl)

## Gold cost to reach the next tier. Returns 0 if already max tier.
func next_tier_cost() -> int:
    if _tier >= TowerTier.IRON:
        return 0
    return TIER_UPGRADE_COST[int(_tier) + 1]

## Upkeep contribution for this tower's current tier (queried by Economy each wave end).
func upkeep_cost() -> int:
    return TIER_UPKEEP[int(_tier)]

## Upgrade this tower to the next tier.
## Called by Main after gold has been deducted.
func upgrade_tier() -> void:
    if _tier >= TowerTier.IRON:
        return
    _tier = (_tier + 1) as TowerTier
    _upgrade_visual()
    tier_upgraded.emit(self, int(_tier))

## Swap sprite and adjust archer count to match new tier.
func _upgrade_visual() -> void:
    ## Replace tower body sprite
    if _tower_sprite != null:
        _tower_sprite.texture = _tier_texture()

    ## Adjust archer count — add third archer when reaching Iron
    var target_count: int = TIER_ARCHER_COUNT[int(_tier)]
    while _archer_sprites.size() < target_count:
        var af := Sprite2D.new()
        af.texture = load("res://assets/sprites/garrison/archer_0.png")
        af.scale = Vector2(0.36, 0.36)
        add_child(af)
        _archer_sprites.append(af)

    ## Reposition archers based on count
    _reposition_archers()

## Return the correct texture resource for the current tier.
func _tier_texture() -> Texture2D:
    match _tier:
        TowerTier.STONE: return load("res://assets/sprites/garrison/archer_tower_t2.png")
        TowerTier.IRON:  return load("res://assets/sprites/garrison/archer_tower_t3.png")
        _:               return load("res://assets/sprites/garrison/archer_tower_t1.png")

## Reposition archer sprites symmetrically based on count.
func _reposition_archers() -> void:
    match _archer_sprites.size():
        2:
            _archer_sprites[0].position = Vector2(-22.0, -52.0)
            _archer_sprites[1].position = Vector2( 22.0, -52.0)
        3:
            _archer_sprites[0].position = Vector2(-26.0, -52.0)
            _archer_sprites[1].position = Vector2(  0.0, -52.0)
            _archer_sprites[2].position = Vector2( 26.0, -52.0)
```

### Changes to _ready() in archer_tower.gd

Replace the anonymous sprite creation with tracked references:

```gdscript
func _ready() -> void:
    var shadow := Sprite2D.new()
    shadow.texture = load("res://assets/sprites/garrison/shadow.png")
    shadow.position = Vector2(0.0, 42.0)
    shadow.scale = Vector2(2.2, 2.2)
    add_child(shadow)

    ## Track tower body sprite for tier upgrade swaps
    _tower_sprite = Sprite2D.new()
    _tower_sprite.texture = load("res://assets/sprites/garrison/archer_tower_t1.png")
    _tower_sprite.scale = Vector2(0.88, 0.88)
    add_child(_tower_sprite)

    ## Two archers at Tier 1 — tracked for tier-based repositioning
    for i in range(2):
        var af := Sprite2D.new()
        af.texture = load("res://assets/sprites/garrison/archer_0.png")
        af.scale = Vector2(0.36, 0.36)
        af.position = Vector2(-22.0 + i * 44.0, -52.0)
        add_child(af)
        _archer_sprites.append(af)

    _power_label = Label.new()
    _power_label.position = Vector2(-30.0, -85.0)
    _power_label.size = Vector2(60.0, 22.0)
    _power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _power_label.add_theme_font_size_override("font_size", 13)
    add_child(_power_label)
```

### Changes to _process() and _fire_at_nearest_enemy() in archer_tower.gd

Replace inline damage/ivtl computation with the new formula methods:

```gdscript
func _process(delta: float) -> void:
    if GameStateMachine.current_state != GameStateMachine.State.PLAYING:
        return
    _shoot_timer += delta
    if _shoot_timer >= effective_ivtl():
        _shoot_timer = 0.0
        _fire_at_nearest_enemy()

func _fire_at_nearest_enemy() -> void:
    if _arrow_pool == null or _enemy_wave == null:
        return
    var target: Node = _find_nearest_enemy_in_range(effective_range())
    if target == null:
        return
    var dir: Vector2 = (target.position - position).normalized()
    var arrow_dmg: int = effective_damage()
    ## Fire power damage boost already factored through FIRE_DMG_MULT if FIRE active
    ## Note: effective_damage() returns tier-scaled base; FIRE mult applies on top
    if _power == TowerPower.FIRE:
        arrow_dmg = roundi(float(arrow_dmg) * FIRE_DMG_MULT)
    var slow_f: float = SLOW_FACTOR if _power == TowerPower.WATER else 1.0
    var slow_d: float = SLOW_DURATION if _power == TowerPower.WATER else 0.0
    var archer_count: int = TIER_ARCHER_COUNT[int(_tier)]
    for i in range(archer_count):
        var arrow: Node = _arrow_pool.checkout()
        if arrow == null:
            break
        var spread := Vector2(-dir.y, dir.x) * (float(i) - float(archer_count - 1) / 2.0) * 6.0
        arrow.activate(position + spread, dir, _arrow_pool, arrow_dmg, slow_f, slow_d)
```

---

## economy.gd — additions

```gdscript
## Reference to all active towers — replaces _tower_count scalar for per-tower upkeep.
## Set by Main via set_tower_list() after each tower purchase.
var _towers: Array[Node2D] = []

## Register the live tower list (called by Main after _towers changes).
func set_tower_list(towers: Array[Node2D]) -> void:
    _towers = towers

## Cost to upgrade a specific tower to its next tier. Returns 0 if max tier.
## Called by HUD to decide whether to show/grey out the UPGRADE button.
func tower_upgrade_cost(tower: Node2D) -> int:
    if tower.has_method("next_tier_cost"):
        return tower.next_tier_cost()
    return 0

## Attempt to upgrade a tower. Returns true if gold was spent and tier increased.
func try_upgrade_tower(tower: Node2D) -> bool:
    var cost: int = tower_upgrade_cost(tower)
    if cost <= 0:
        return false
    if not spend_gold(cost):
        return false
    tower.upgrade_tier()
    return true

## Modified _on_wave_cleared — uses per-tower upkeep instead of fixed constant.
func _on_wave_cleared() -> void:
    if GameStateMachine.current_state == GameStateMachine.State.GAME_OVER:
        return
    var archer_upkeep: int = _current_archer_count * UPKEEP_PER_ARCHER
    var tower_upkeep: int = 0
    for t: Node2D in _towers:
        if t.has_method("upkeep_cost"):
            tower_upkeep += t.upkeep_cost()
        else:
            tower_upkeep += UPKEEP_PER_TOWER    ## fallback for untyped nodes
    var upkeep: int = archer_upkeep + tower_upkeep
    if upkeep <= 0:
        return
    var deducted: int = mini(current_gold, upkeep)
    current_gold = maxi(0, current_gold - upkeep)
    gold_changed.emit(current_gold)
    if deducted > 0:
        upkeep_deducted.emit(deducted)
```

---

## Main.gd — additions

```gdscript
## Pass the live tower list to Economy after each purchase so upkeep is computed correctly.
func _on_tower_purchased() -> void:
    if _towers.size() >= MAX_TOWERS:
        return
    var tower: Node2D = Node2D.new()
    tower.set_script(load("res://src/gameplay/archer_tower.gd"))
    tower.position = TOWER_POSITIONS[_towers.size()]
    tower.setup(_arrow_pool, _enemy_wave, _forge)
    tower.power_requested.connect(_on_tower_power_requested.bind(tower))
    $GameWorld.add_child(tower)
    _towers.append(tower)
    ## Keep Economy's tower list in sync
    _economy.set_tower_list(_towers)

## Extend the tower power response to also offer tier upgrades.
## Called when a tower is tapped.
func _on_tower_power_requested(tower: Node2D) -> void:
    _hud.show_power_panel(tower, _economy)

## Apply a tier upgrade if affordable. Called by HUD upgrade button signal.
func _apply_tower_upgrade(tower: Node) -> void:
    _economy.try_upgrade_tower(tower)

## Wire the HUD upgrade signal (add to _wire_signals):
## _hud.power_upgrade_pressed.connect(func(t: Node) -> void: _apply_tower_upgrade(t))
```

---

## hud.gd — show_power_panel() extension

The existing `show_power_panel(tower: Node2D)` method needs a second parameter and an
UPGRADE button. The minimal change:

```gdscript
## Extended signature — economy ref allows cost display and affordability check.
func show_power_panel(tower: Node2D, economy: Node = null) -> void:
    ## ... existing panel build code ...

    ## UPGRADE button — shown only if tower is below max tier
    var upgrade_cost: int = 0
    if economy != null and tower.has_method("next_tier_cost"):
        upgrade_cost = tower.next_tier_cost()

    if upgrade_cost > 0:
        var upgrade_btn := Button.new()
        upgrade_btn.text = "AMELIORER %dg" % upgrade_cost
        upgrade_btn.disabled = (economy.current_gold < upgrade_cost)
        ## position below the three power buttons
        upgrade_btn.position = Vector2(...)   ## fit within existing panel layout
        upgrade_btn.pressed.connect(func() -> void:
            power_upgrade_pressed.emit(tower)
            _hide_power_panel()
        )
        _power_panel.add_child(upgrade_btn)

## New signal to declare at the top of hud.gd:
signal power_upgrade_pressed(tower: Node2D)
```

---

---

# Test Plan

## Unit tests to add (tests/unit/gameplay/test_archer_tower_tiers.gd)

```
test_t1_range_is_350
test_t2_range_is_420
test_t3_range_is_510
test_t1_damage_uses_forge_base_only
test_t2_damage_is_1_30x_forge
test_t3_damage_is_1_65x_forge
test_t1_ivtl_uses_forge_base_only
test_t2_ivtl_is_0_82x_forge
test_t3_ivtl_is_0_65x_forge
test_ivtl_never_below_0_40s_at_t3_lightning
test_upkeep_t1_is_8
test_upkeep_t2_is_12
test_upkeep_t3_is_18
test_upgrade_from_t1_costs_200g
test_upgrade_from_t2_costs_350g
test_upgrade_at_max_tier_returns_false
test_power_preserved_after_tier_upgrade
test_archer_count_is_2_at_t1_and_t2
test_archer_count_is_3_at_t3
test_next_tier_cost_0_at_iron
```

---

# Implementation Sequence

Follow the 4-phase rule from global CLAUDE.md:

**Phase 1 — Read** (done in this session):
archer_tower.gd, economy.gd, Main.gd, forge.gd, gen_sprites.py all read in full.

**Phase 2 — Sprites first** (before any GDScript changes):
1. Add palette entries to gen_sprites.py
2. Add gen_tower_t1(), gen_tower_t2(), gen_tower_t3() functions
3. Add save calls, replacing existing gen_tower() call
4. Run: `python3 tools/gen_sprites.py` — verify three PNG outputs exist in assets/sprites/garrison/
5. Open Godot once to trigger .import file generation for all three PNGs

**Phase 3 — GDScript** (after sprites confirmed importable):
1. archer_tower.gd: add enum, consts, tracked sprites in _ready(), formula methods,
   upgrade_tier(), _upgrade_visual(), _reposition_archers(), update _process() and
   _fire_at_nearest_enemy()
2. economy.gd: add _towers list, set_tower_list(), tower_upgrade_cost(), try_upgrade_tower(),
   update _on_wave_cleared()
3. Main.gd: update _on_tower_purchased() to call set_tower_list(), add _apply_tower_upgrade(),
   wire new HUD signal
4. hud.gd: extend show_power_panel() signature, add UPGRADE button, add power_upgrade_pressed signal

**Phase 4 — Tests and validation**:
1. Write test_archer_tower_tiers.gd covering the 20 test cases above
2. Run GUT: verify all pass, 0 failing, no regression in existing 23 scripts
3. Smoke check: open Godot, place a tower, upgrade it twice, verify sprite swaps and archer
   count change, verify power survives upgrade
