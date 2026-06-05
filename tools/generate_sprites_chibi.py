#!/usr/bin/env python3
"""
Garrison — Chibi/Fantastic World Sprite Generator
Iteration 1 of the Master Chibi Loop

Generates missing sprites not covered by gen_sprites.py:
  - spell_hit VFX  (fire / lightning / ice)
  - RPG décors     (herb / mushroom / plant)
  - Ambient creatures (bunny / squirrel / bird / deer / crow)
  - RPG enemies    (goblin / dark-elf / skeleton-mage)

Style rules:
  - Chibi: head = 55% of total height, big 2-dot eyes, stubby body
  - 2px black outline on all characters
  - Saturated palette, warm highlights
  - Magic: PIL GaussianBlur glow layer underneath
"""

from PIL import Image, ImageDraw, ImageFilter
import os, math

OUT = "/home/marpeap/Bureau/Game Developping/Claude-Code-Game-Studios/assets/sprites/garrison"
S = 3   # supersampling factor — draw at 3× then downscale with LANCZOS

# ─── TRANSPARENT BASE ──────────────────────────────────────────────────────

T   = (0, 0, 0, 0)
OL  = (12, 8, 4, 250)   # outline colour

# ─── HELPERS ────────────────────────────────────────────────────────────────

def px(v):
    return int(v * S)

def new(w, h):
    return Image.new("RGBA", (w * S, h * S), T)

def rect(d, x1, y1, x2, y2, fill):
    d.rectangle([x1, y1, x2, y2], fill=fill)

def ell(d, cx, cy, rx, ry, fill):
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=fill)

def poly(d, pts, fill):
    d.polygon(pts, fill=fill)

def line(d, pts, fill, width=1):
    d.line(pts, fill=fill, width=width)

def add_outline(img, thickness=2):
    _, _, _, a = img.split()
    mask = a.filter(ImageFilter.MaxFilter(thickness * 2 + 1))
    ol_data = [(OL if v > 18 else (0, 0, 0, 0)) for v in mask.getdata()]
    ol = Image.new("RGBA", img.size)
    ol.putdata(ol_data)
    res = Image.new("RGBA", img.size, T)
    res.paste(ol)
    res.paste(img, mask=img)
    return res

def glow_layer(img, color, radius=4, alpha_factor=0.55):
    """Generate a blurred glow beneath the image."""
    _, _, _, a = img.split()
    glow = Image.new("RGBA", img.size, T)
    gd = ImageDraw.Draw(glow)
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            if a.getpixel((x, y)) > 30:
                gd.point((x, y), fill=color + (int(200 * alpha_factor),))
    glow = glow.filter(ImageFilter.GaussianBlur(radius))
    result = Image.new("RGBA", img.size, T)
    result.paste(glow, mask=glow)
    result.paste(img, mask=img)
    return result

def save(img, name, fw, fh, outline=True, glow=None):
    if glow is not None:
        img = glow_layer(img, glow)
    if outline:
        img = add_outline(img)
    final = img.resize((fw, fh), Image.LANCZOS)
    final.save(os.path.join(OUT, name))
    print(f"  ✓ {name}  ({fw}×{fh})")


# ════════════════════════════════════════════════════════════════════════════
# SPELL HIT VFX  —  48×48
# ════════════════════════════════════════════════════════════════════════════

def gen_spell_hit_fire():
    """Fire explosion burst — orange/red starburst with yellow core."""
    W, H = 48, 48
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx, cy = W * S // 2, H * S // 2

    # Outer burst petals
    for i in range(8):
        angle = math.radians(i * 45)
        bx = cx + int(math.cos(angle) * px(14))
        by = cy + int(math.sin(angle) * px(14))
        ell(d, bx, by, px(8), px(8), (228, 80, 22, 200))

    # Mid ring
    for i in range(12):
        angle = math.radians(i * 30 + 15)
        bx = cx + int(math.cos(angle) * px(9))
        by = cy + int(math.sin(angle) * px(9))
        ell(d, bx, by, px(5), px(5), (255, 142, 42, 210))

    # Core glow
    ell(d, cx, cy, px(10), px(10), (255, 218, 80, 230))
    ell(d, cx, cy, px(5),  px(5),  (255, 255, 200, 250))

    save(img, "spell_hit_fire.png", W, H, outline=False, glow=(255, 90, 20))


def gen_spell_hit_lightning():
    """Lightning impact — jagged white-yellow bolts radiating outward."""
    W, H = 48, 48
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx, cy = W * S // 2, H * S // 2

    # 6 zigzag bolts
    bolt_col = (240, 230, 60, 240)
    bolt_w   = (200, 200, 50, 220)
    for i in range(6):
        base_angle = math.radians(i * 60)
        r = px(16)
        mid_r = px(9)
        # start at center, zigzag to outer
        ex = cx + int(math.cos(base_angle) * r)
        ey = cy + int(math.sin(base_angle) * r)
        off_angle = base_angle + math.radians(30)
        mx = cx + int(math.cos(off_angle) * mid_r)
        my = cy + int(math.sin(off_angle) * mid_r)
        line(d, [(cx, cy), (mx, my), (ex, ey)], fill=bolt_col, width=max(2, px(1)))
        # white inner core
        line(d, [(cx, cy), (mx, my), (ex, ey)], fill=(255, 255, 255, 200), width=max(1, px(1) // 2))

    # Bright center
    ell(d, cx, cy, px(7), px(7), (200, 240, 255, 230))
    ell(d, cx, cy, px(3), px(3), (255, 255, 255, 255))

    # Spark dots
    for i in range(10):
        angle = math.radians(i * 36)
        sx = cx + int(math.cos(angle) * px(12))
        sy = cy + int(math.sin(angle) * px(12))
        ell(d, sx, sy, px(2), px(2), bolt_col)

    save(img, "spell_hit_lightning.png", W, H, outline=False, glow=(180, 220, 255))


def gen_spell_hit_ice():
    """Ice crystal burst — cyan/white shards with snowflake pattern."""
    W, H = 48, 48
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx, cy = W * S // 2, H * S // 2

    ice_main  = (120, 210, 245, 230)
    ice_light = (200, 240, 255, 220)
    ice_dark  = ( 60, 140, 195, 200)
    ice_white = (240, 250, 255, 250)

    # 6 main crystal shards
    for i in range(6):
        angle = math.radians(i * 60)
        r_out = px(16)
        r_in  = px(4)
        tip_x = cx + int(math.cos(angle) * r_out)
        tip_y = cy + int(math.sin(angle) * r_out)
        l_angle = angle + math.radians(18)
        r_angle = angle - math.radians(18)
        base_lx = cx + int(math.cos(l_angle) * r_in)
        base_ly = cy + int(math.sin(l_angle) * r_in)
        base_rx = cx + int(math.cos(r_angle) * r_in)
        base_ry = cy + int(math.sin(r_angle) * r_in)
        poly(d, [(tip_x, tip_y), (base_lx, base_ly), (base_rx, base_ry)], ice_main)
        # highlight streak
        hl_x = cx + int(math.cos(angle) * px(12))
        hl_y = cy + int(math.sin(angle) * px(12))
        line(d, [(cx, cy), (hl_x, hl_y)], fill=ice_light, width=max(1, px(1)))

    # Inner snowflake cross arms
    for i in range(4):
        angle = math.radians(i * 45 + 22)
        ex = cx + int(math.cos(angle) * px(8))
        ey = cy + int(math.sin(angle) * px(8))
        line(d, [(cx, cy), (ex, ey)], fill=ice_dark, width=max(2, px(1)))

    # Core
    ell(d, cx, cy, px(6), px(6), ice_light)
    ell(d, cx, cy, px(3), px(3), ice_white)

    save(img, "spell_hit_ice.png", W, H, outline=False, glow=(80, 190, 240))


# ════════════════════════════════════════════════════════════════════════════
# RPG DÉCORS  —  32×32
# ════════════════════════════════════════════════════════════════════════════

def gen_herb():
    """Chibi herb plant — three green leaves fanning upward."""
    W, H = 32, 32
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx = W * S // 2

    stem_x = cx
    stem_top = px(6)
    stem_bot = px(26)

    # Stem
    rect(d, stem_x - px(1), stem_top, stem_x + px(1), stem_bot, (72, 110, 55))

    # 3 leaves: left, center, right
    # Center leaf (tallest)
    leaf_c = [(stem_x, stem_top),
              (stem_x - px(4), stem_top + px(5)),
              (stem_x - px(2), stem_top + px(11)),
              (stem_x, stem_top + px(9)),
              (stem_x + px(2), stem_top + px(11)),
              (stem_x + px(4), stem_top + px(5))]
    poly(d, leaf_c, (90, 162, 70))

    # Left leaf
    lx = stem_x - px(5)
    leaf_l = [(lx, stem_top + px(5)),
              (lx - px(5), stem_top + px(10)),
              (lx - px(2), stem_top + px(15)),
              (stem_x - px(1), stem_top + px(12))]
    poly(d, leaf_l, (78, 140, 60))

    # Right leaf
    rx = stem_x + px(5)
    leaf_r = [(rx, stem_top + px(5)),
              (rx + px(5), stem_top + px(10)),
              (rx + px(2), stem_top + px(15)),
              (stem_x + px(1), stem_top + px(12))]
    poly(d, leaf_r, (78, 140, 60))

    # Tiny white flower
    ell(d, stem_x, stem_top - px(1), px(3), px(3), (245, 245, 230, 220))
    ell(d, stem_x, stem_top - px(1), px(1), px(1), (255, 200, 80, 240))

    # Ground dot
    ell(d, stem_x, stem_bot + px(2), px(4), px(2), (72, 110, 55, 160))

    save(img, "herb.png", W, H)


def gen_mushroom():
    """Chibi mushroom — red cap with white spots, pale stem."""
    W, H = 32, 32
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx = W * S // 2

    stem_bot = px(27)
    stem_top = px(17)
    cap_cy   = px(12)

    # Stem
    trap_pts = [
        (cx - px(4), stem_top),
        (cx + px(4), stem_top),
        (cx + px(5), stem_bot),
        (cx - px(5), stem_bot),
    ]
    poly(d, trap_pts, (215, 200, 178))
    # Stem highlight
    rect(d, cx - px(1), stem_top + px(1), cx + px(1), stem_bot - px(2), (235, 225, 205))

    # Cap
    ell(d, cx, cap_cy, px(12), px(11), (208, 52, 42))
    # Cap underside rim
    rect(d, cx - px(12), stem_top, cx + px(12), stem_top + px(3), (188, 162, 140))
    ell(d, cx, stem_top, px(12), px(3), (188, 162, 140))
    # Cap highlight
    ell(d, cx - px(4), cap_cy - px(4), px(5), px(4), (240, 90, 80, 180))
    # White spots
    spot_positions = [
        (cx, cap_cy - px(4)),
        (cx - px(6), cap_cy + px(2)),
        (cx + px(6), cap_cy + px(2)),
        (cx - px(2), cap_cy + px(5)),
    ]
    for sx, sy in spot_positions:
        ell(d, sx, sy, px(2), px(2), (248, 245, 238))

    save(img, "mushroom.png", W, H)


def gen_plant():
    """Chibi flowering plant — round pot, leafy bush, pink blossom."""
    W, H = 32, 32
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx = W * S // 2

    pot_top  = px(20)
    pot_bot  = px(28)

    # Pot
    trap_pts = [
        (cx - px(4), pot_top),
        (cx + px(4), pot_top),
        (cx + px(6), pot_bot),
        (cx - px(6), pot_bot),
    ]
    poly(d, trap_pts, (168, 98, 62))
    # Pot rim
    rect(d, cx - px(5), pot_top - px(1), cx + px(5), pot_top + px(2), (200, 128, 85))

    # Leaves (bushy cluster)
    leaf_col  = (72, 148, 60)
    leaf_col2 = (95, 172, 78)
    ell(d, cx,         px(13), px(9),  px(9),  leaf_col)
    ell(d, cx - px(7), px(14), px(7),  px(7),  leaf_col)
    ell(d, cx + px(7), px(14), px(7),  px(7),  leaf_col)
    ell(d, cx,         px(8),  px(6),  px(6),  leaf_col2)

    # Pink blossom
    for i in range(5):
        angle = math.radians(i * 72)
        bx = cx + int(math.cos(angle) * px(4))
        by = px(8)  + int(math.sin(angle) * px(3))
        ell(d, bx, by, px(3), px(3), (240, 148, 168, 220))
    ell(d, cx, px(8), px(2), px(2), (255, 220, 90))

    save(img, "plant.png", W, H)


# ════════════════════════════════════════════════════════════════════════════
# AMBIENT CREATURES  —  side-view, tiny chibi animals
# ════════════════════════════════════════════════════════════════════════════

def gen_ambient_bunny():
    """Chibi bunny — 28×28 white/cream, big ears, dot eyes."""
    W, H = 28, 28
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx = W * S // 2

    body_cx = cx + px(2)
    body_cy = px(18)

    # Body
    ell(d, body_cx, body_cy, px(8), px(6), (230, 220, 205))
    # Head
    head_cx = cx - px(4)
    head_cy = px(12)
    ell(d, head_cx, head_cy, px(6), px(6), (230, 220, 205))
    # Head highlight
    ell(d, head_cx - px(1), head_cy - px(2), px(3), px(2), (245, 238, 228, 160))
    # Ears
    ell(d, head_cx - px(3), head_cy - px(10), px(2), px(6), (220, 210, 198))
    ell(d, head_cx + px(1), head_cy - px(9),  px(2), px(6), (220, 210, 198))
    ell(d, head_cx - px(3), head_cy - px(10), px(1), px(4), (225, 170, 170, 200))
    ell(d, head_cx + px(1), head_cy - px(9),  px(1), px(4), (225, 170, 170, 200))
    # Eye
    ell(d, head_cx + px(2), head_cy - px(1), px(2), px(2), (38, 28, 18))
    ell(d, head_cx + px(2), head_cy - px(1), px(1), px(1), (255, 255, 255, 180))
    # Nose
    ell(d, head_cx + px(4), head_cy + px(2), px(1), px(1), (228, 148, 148))
    # Tail
    ell(d, body_cx + px(7), body_cy - px(1), px(3), px(3), (240, 235, 228))
    # Feet
    ell(d, body_cx - px(3), body_cy + px(5), px(4), px(2), (220, 210, 198))
    ell(d, body_cx + px(2), body_cy + px(5), px(4), px(2), (220, 210, 198))

    save(img, "ambient_bunny.png", W, H)


def gen_ambient_squirrel():
    """Chibi squirrel — 28×28 orange-brown, bushy tail, nut-holding pose."""
    W, H = 28, 28
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx = W * S // 2

    FUR_L = (195, 135,  72)
    FUR_M = (165, 105,  52)
    FUR_D = (125,  78,  38)
    TAIL  = (185, 128,  60)
    BLY   = (232, 215, 192)   # belly light

    body_cx = cx
    body_cy = px(18)

    # Tail (bushy, curves up behind)
    for r in range(px(9), 0, -1):
        alpha = int(200 * (r / px(9)))
        tcx = body_cx + px(8)
        tcy = px(10)
        ell(d, tcx, tcy, r, r, TAIL + (alpha,))

    # Body
    ell(d, body_cx, body_cy, px(6), px(7), FUR_M)
    # Belly
    ell(d, body_cx + px(1), body_cy + px(2), px(3), px(4), BLY)
    # Head
    head_cx = body_cx - px(2)
    head_cy = px(11)
    ell(d, head_cx, head_cy, px(5), px(5), FUR_L)
    # Ears
    ell(d, head_cx - px(2), head_cy - px(6), px(2), px(3), FUR_L)
    ell(d, head_cx + px(2), head_cy - px(5), px(2), px(3), FUR_L)
    # Eye
    ell(d, head_cx + px(2), head_cy - px(1), px(2), px(2), (28, 20, 12))
    ell(d, head_cx + px(2), head_cy - px(1), px(1), px(1), (255, 255, 255, 160))
    # Arms holding nut
    ell(d, head_cx + px(5), head_cy + px(6), px(3), px(2), FUR_M)
    # Nut
    ell(d, head_cx + px(7), head_cy + px(7), px(3), px(3), (175, 128, 62))
    # Feet
    ell(d, body_cx - px(3), body_cy + px(6), px(3), px(2), FUR_D)
    ell(d, body_cx + px(2), body_cy + px(6), px(3), px(2), FUR_D)

    save(img, "ambient_squirrel.png", W, H)


def gen_ambient_bird():
    """Chibi bird — 24×24 blue jay, perched with puffed chest."""
    W, H = 24, 24
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx = W * S // 2

    BD_L  = ( 88, 148, 210)
    BD_M  = ( 62, 118, 182)
    BD_D  = ( 42,  88, 148)
    CHEST = (235, 215, 195)
    BEAK  = (195, 165,  75)

    body_cx = cx
    body_cy = px(14)

    # Body
    ell(d, body_cx, body_cy, px(7), px(6), BD_M)
    # Wing detail
    ell(d, body_cx + px(2), body_cy, px(5), px(4), BD_D)
    # Chest
    ell(d, body_cx - px(2), body_cy + px(2), px(4), px(4), CHEST)
    # Head
    head_cx = body_cx - px(3)
    head_cy = px(8)
    ell(d, head_cx, head_cy, px(5), px(5), BD_L)
    # Crest
    for i in range(3):
        ell(d, head_cx - px(1) + px(i), head_cy - px(5) - px(i), px(1), px(2), BD_M)
    # Eye
    ell(d, head_cx + px(2), head_cy - px(1), px(2), px(2), (22, 16, 10))
    ell(d, head_cx + px(2), head_cy - px(1), px(1), px(1), (255, 255, 255, 180))
    # Beak
    poly(d, [(head_cx + px(4), head_cy + px(1)),
             (head_cx + px(8), head_cy - px(1)),
             (head_cx + px(4), head_cy + px(3))], BEAK)
    # Feet / branch grip
    line(d, [(body_cx - px(3), body_cy + px(5)), (body_cx + px(3), body_cy + px(5))],
         fill=(85, 65, 40), width=max(1, px(1)))
    ell(d, body_cx - px(2), body_cy + px(5), px(1), px(1), (85, 65, 40))
    ell(d, body_cx + px(2), body_cy + px(5), px(1), px(1), (85, 65, 40))

    save(img, "ambient_bird.png", W, H)


def gen_ambient_deer():
    """Chibi deer — 36×32 golden-brown, antlers, white belly."""
    W, H = 36, 32
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx = W * S // 2

    DR_L  = (210, 170, 100)
    DR_M  = (178, 135,  72)
    DR_D  = (135, 100,  48)
    BELLY = (238, 225, 198)
    ANTL  = (138,  95,  50)
    NOSE  = (245, 175, 170)

    body_cx = cx + px(4)
    body_cy = px(20)

    # Body
    ell(d, body_cx, body_cy, px(12), px(8), DR_M)
    # Back shadow
    ell(d, body_cx + px(4), body_cy + px(2), px(7), px(5), DR_D)
    # Belly
    ell(d, body_cx - px(4), body_cy + px(2), px(7), px(5), BELLY)
    # Head
    head_cx = cx - px(8)
    head_cy = px(13)
    ell(d, head_cx, head_cy, px(7), px(6), DR_L)
    # Snout
    ell(d, head_cx - px(5), head_cy + px(2), px(4), px(3), DR_M)
    ell(d, head_cx - px(7), head_cy + px(2), px(2), px(2), NOSE)
    # Eye
    ell(d, head_cx - px(1), head_cy - px(2), px(2), px(2), (28, 20, 10))
    ell(d, head_cx - px(1), head_cy - px(2), px(1), px(1), (255, 255, 255, 180))
    # Ear
    ell(d, head_cx + px(4), head_cy - px(5), px(4), px(2), DR_L)
    # Antlers
    antl_base_x = head_cx + px(2)
    antl_base_y = head_cy - px(6)
    line(d, [(antl_base_x, antl_base_y),
             (antl_base_x - px(2), antl_base_y - px(8)),
             (antl_base_x - px(5), antl_base_y - px(12))], fill=ANTL, width=max(2, px(1)))
    line(d, [(antl_base_x - px(2), antl_base_y - px(5)),
             (antl_base_x + px(1), antl_base_y - px(9))], fill=ANTL, width=max(1, px(1)))
    # Neck
    poly(d, [(head_cx + px(4), head_cy),
             (head_cx + px(7), head_cy + px(4)),
             (body_cx - px(8), body_cy - px(4)),
             (body_cx - px(10), body_cy - px(7))], DR_M)
    # Legs (4 simple lines)
    for lx in [body_cx - px(7), body_cx - px(3), body_cx + px(3), body_cx + px(7)]:
        rect(d, lx - px(2), body_cy + px(7), lx + px(2), body_cy + px(16), DR_D)
        ell(d, lx, body_cy + px(16), px(2), px(1), (88, 65, 42))  # hoof

    save(img, "ambient_deer.png", W, H)


def gen_ambient_crow():
    """Chibi crow — 26×22 glossy black, perched, beady yellow eye."""
    W, H = 26, 22
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx = W * S // 2

    CR_M = ( 38,  35,  42)
    CR_L = ( 68,  62,  72)
    CR_SH= ( 22,  18,  26)
    BEAK = (175, 158,  50)
    EYE  = (218, 195,  52)

    body_cx = cx
    body_cy = px(13)

    # Body
    ell(d, body_cx, body_cy, px(8), px(6), CR_M)
    # Wing sheen
    ell(d, body_cx + px(2), body_cy - px(1), px(6), px(4), CR_L)
    # Tail feathers
    poly(d, [(body_cx + px(5), body_cy + px(2)),
             (body_cx + px(12), body_cy + px(4)),
             (body_cx + px(10), body_cy + px(6)),
             (body_cx + px(6),  body_cy + px(4))], CR_SH)
    # Head
    head_cx = body_cx - px(4)
    head_cy = px(7)
    ell(d, head_cx, head_cy, px(5), px(5), CR_M)
    # Eye
    ell(d, head_cx + px(2), head_cy, px(3), px(3), EYE)
    ell(d, head_cx + px(2), head_cy, px(2), px(2), (22, 18, 12))
    ell(d, head_cx + px(1), head_cy - px(1), px(1), px(1), (255, 255, 255, 180))
    # Beak
    poly(d, [(head_cx - px(2), head_cy + px(1)),
             (head_cx - px(7), head_cy - px(1)),
             (head_cx - px(2), head_cy + px(3))], BEAK)
    # Feet
    line(d, [(body_cx - px(3), body_cy + px(6)), (body_cx + px(3), body_cy + px(6))],
         fill=(65, 55, 42), width=max(1, px(1)))
    for fx in [body_cx - px(2), body_cx + px(2)]:
        ell(d, fx, body_cy + px(6), px(1), px(1), (65, 55, 42))

    save(img, "ambient_crow.png", W, H)


# ════════════════════════════════════════════════════════════════════════════
# RPG ENEMIES  —  chibi 48×48 fantasy warriors
# ════════════════════════════════════════════════════════════════════════════

def gen_rpg_enemy_goblin():
    """RPG Enemy 0 — Chibi Goblin Warrior: green skin, rusty armour, big ears."""
    W, H = 48, 48
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx = W * S // 2

    GBL  = ( 98, 158,  78)   # goblin skin light
    GBM  = ( 72, 125,  55)   # skin mid
    GBD  = ( 48,  92,  35)   # skin dark
    ARM  = (142, 118,  72)   # rusty armour
    ARMD = (105,  85,  52)
    EY   = (255, 215,  40)   # yellow goblin eye
    HR   = ( 38,  28,  18)   # hair
    WPN  = (148, 128, 105)   # weapon (crude axe)
    WPND = ( 98,  82,  65)
    BLD  = (215,  68,  52)   # blood-red detail

    # Body (stout, low center of gravity)
    body_cy = px(30)
    ell(d, cx, body_cy, px(10), px(9), GBM)
    # Armour vest front
    poly(d, [(cx - px(7), px(25)), (cx + px(7), px(25)),
             (cx + px(8), px(35)), (cx - px(8), px(35))], ARM)
    # Armour shadow
    poly(d, [(cx + px(2), px(25)), (cx + px(7), px(25)),
             (cx + px(8), px(35)), (cx + px(2), px(35))], ARMD)
    # Belt
    rect(d, cx - px(9), px(34), cx + px(9), px(37), ARMD)
    ell(d, cx, px(35), px(3), px(2), (188, 158, 88))  # buckle

    # Head (chibi — large, ~50% canvas height)
    head_cy = px(14)
    ell(d, cx, head_cy, px(13), px(13), GBL)
    # Head shading
    ell(d, cx + px(4), head_cy + px(4), px(8), px(7), GBM)
    # Big ears
    ell(d, cx - px(14), head_cy + px(2), px(5), px(7), GBL)
    ell(d, cx + px(14), head_cy + px(2), px(5), px(7), GBL)
    ell(d, cx - px(14), head_cy + px(2), px(3), px(5), GBD)
    ell(d, cx + px(14), head_cy + px(2), px(3), px(5), GBD)
    # Eyebrow ridge (angry)
    rect(d, cx - px(9), head_cy - px(5), cx - px(3), head_cy - px(3), GBD)
    rect(d, cx + px(3), head_cy - px(5), cx + px(9), head_cy - px(3), GBD)
    # Eyes
    ell(d, cx - px(5), head_cy - px(1), px(4), px(4), EY)
    ell(d, cx + px(5), head_cy - px(1), px(4), px(4), EY)
    ell(d, cx - px(5), head_cy - px(1), px(2), px(2), (22, 14, 8))
    ell(d, cx + px(5), head_cy - px(1), px(2), px(2), (22, 14, 8))
    # Snout
    ell(d, cx, head_cy + px(6), px(6), px(4), GBM)
    ell(d, cx - px(3), head_cy + px(7), px(2), px(2), GBD)
    ell(d, cx + px(3), head_cy + px(7), px(2), px(2), GBD)
    # Fangs
    poly(d, [(cx - px(4), head_cy + px(8)),
             (cx - px(3), head_cy + px(12)),
             (cx - px(2), head_cy + px(8))], (238, 228, 205))
    poly(d, [(cx + px(2), head_cy + px(8)),
             (cx + px(3), head_cy + px(12)),
             (cx + px(4), head_cy + px(8))], (238, 228, 205))
    # Hair
    for i in range(-2, 3):
        ell(d, cx + px(i * 3), head_cy - px(12), px(3), px(4), HR)

    # Arms
    ell(d, cx - px(14), px(28), px(5), px(8), GBL)   # left arm
    ell(d, cx + px(14), px(27), px(5), px(8), ARM)   # right arm (armoured)
    # Weapon — crude axe
    rect(d, cx + px(15), px(15), cx + px(18), px(35), WPN)  # handle
    poly(d, [(cx + px(14), px(15)),
             (cx + px(24), px(12)),
             (cx + px(24), px(22)),
             (cx + px(14), px(22))], WPND)
    ell(d, cx + px(19), px(17), px(5), px(2), ARM)  # axe highlight

    # Legs
    ell(d, cx - px(5), px(40), px(5), px(7), GBD)
    ell(d, cx + px(5), px(40), px(5), px(7), GBD)
    rect(d, cx - px(8), px(43), cx - px(3), px(47), ARMD)  # boot left
    rect(d, cx + px(3), px(43), cx + px(8), px(47), ARMD)  # boot right

    save(img, "rpg_enemy_0.png", W, H)


def gen_rpg_enemy_dark_elf():
    """RPG Enemy 1 — Chibi Dark Elf Ranger: purple/dark skin, bow, pointed ears."""
    W, H = 48, 48
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx = W * S // 2

    SK   = ( 78,  62, 108)   # dark elf skin (purple-grey)
    SKL  = ( 98,  80, 130)
    SKD  = ( 55,  42,  80)
    CLK  = ( 48,  38,  72)   # dark cloak
    CLKL = ( 68,  55,  95)
    EY   = (178, 235, 178)   # green glow eye
    HR   = (225, 215, 248)   # silver-white hair
    ARML = (158, 145, 195)   # light armour
    ARMD = (115, 105, 148)
    BW   = (112,  82,  55)   # bow wood
    BWL  = (145, 108,  70)

    # Cloak body
    body_cy = px(30)
    poly(d, [(cx - px(10), px(22)), (cx + px(10), px(22)),
             (cx + px(12), px(42)), (cx - px(12), px(42))], CLK)
    poly(d, [(cx + px(2), px(22)),  (cx + px(10), px(22)),
             (cx + px(12), px(42)), (cx + px(2),  px(42))], SKD)
    # Armour chest
    poly(d, [(cx - px(6), px(22)), (cx + px(6), px(22)),
             (cx + px(7), px(32)), (cx - px(7), px(32))], ARML)
    rect(d, cx - px(1), px(22), cx + px(1), px(32), ARMD)  # centre stripe

    # Head
    head_cy = px(13)
    ell(d, cx, head_cy, px(11), px(11), SK)
    ell(d, cx + px(3), head_cy + px(4), px(7), px(6), SKD)
    # Pointed ears
    poly(d, [(cx - px(10), head_cy - px(2)),
             (cx - px(16), head_cy - px(8)),
             (cx - px(8),  head_cy + px(3))], SKL)
    poly(d, [(cx + px(10), head_cy - px(2)),
             (cx + px(16), head_cy - px(8)),
             (cx + px(8),  head_cy + px(3))], SKL)
    # Eyes (glowing green)
    ell(d, cx - px(4), head_cy - px(1), px(3), px(3), EY)
    ell(d, cx + px(4), head_cy - px(1), px(3), px(3), EY)
    ell(d, cx - px(4), head_cy - px(1), px(2), px(2), (18, 12, 8))
    ell(d, cx + px(4), head_cy - px(1), px(2), px(2), (18, 12, 8))
    # Hair (flowing silver)
    for i, (ox, oy, rr, cc) in enumerate([
        (-6, -13, (4, 8), HR), (-2, -14, (3, 9), HR),
        (+2, -14, (3, 9), HR), (+6, -13, (4, 8), HR)
    ]):
        ell(d, cx + px(ox), head_cy + px(oy), px(rr[0]), px(rr[1]), cc)
    # Lips
    rect(d, cx - px(3), head_cy + px(5), cx + px(3), head_cy + px(7), SKD)

    # Arms
    ell(d, cx - px(12), px(27), px(4), px(8), SK)    # left arm
    ell(d, cx + px(12), px(27), px(4), px(7), ARML)  # right arm

    # Bow
    bow_cx = cx - px(18)
    bow_cy = px(24)
    for i in range(-8, 9):
        bx = bow_cx + int(math.sin(math.radians(i * 10)) * px(6))
        by = bow_cy + px(i)
        ell(d, bx, by, px(1), px(1), BW)
    line(d, [(bow_cx - px(6), bow_cy - px(8)), (bow_cx - px(6), bow_cy + px(8))],
         fill=BWL, width=max(2, px(1)))  # bow string
    # Arrow
    line(d, [(bow_cx + px(2), bow_cy), (bow_cx + px(12), bow_cy)],
         fill=(188, 162, 98), width=max(1, px(1)))
    poly(d, [(bow_cx + px(12), bow_cy - px(2)),
             (bow_cx + px(15), bow_cy),
             (bow_cx + px(12), bow_cy + px(2))], (210, 80, 60))

    # Legs
    ell(d, cx - px(5), px(40), px(4), px(6), CLK)
    ell(d, cx + px(5), px(40), px(4), px(6), CLK)
    rect(d, cx - px(8), px(43), cx - px(2), px(47), SKD)  # boot
    rect(d, cx + px(2), px(43), cx + px(8), px(47), SKD)

    save(img, "rpg_enemy_1.png", W, H)


def gen_rpg_enemy_skeleton_mage():
    """RPG Enemy 2 — Chibi Skeleton Mage: bone-white, glowing purple robe, staff."""
    W, H = 48, 48
    img = new(W, H)
    d = ImageDraw.Draw(img)
    cx = W * S // 2

    BONE  = (228, 222, 205)
    BONED = (178, 170, 148)
    BONEX = (128, 122, 105)
    ROBE  = ( 88,  55, 142)
    ROBEL = (118,  80, 175)
    ROBED = ( 55,  32,  92)
    EY    = (188, 148, 255)   # purple glow eyes
    STAFF = (115,  85,  55)
    ORBL  = (208, 158, 255)
    ORBM  = (158,  88, 228)

    # Robe body
    poly(d, [(cx - px(9), px(22)), (cx + px(9), px(22)),
             (cx + px(11), px(44)), (cx - px(11), px(44))], ROBE)
    poly(d, [(cx + px(2), px(22)), (cx + px(9), px(22)),
             (cx + px(11), px(44)), (cx + px(2), px(44))], ROBED)
    # Robe collar
    poly(d, [(cx - px(5), px(22)), (cx + px(5), px(22)),
             (cx + px(6), px(28)), (cx - px(6), px(28))], ROBEL)
    # Robe trim
    rect(d, cx - px(11), px(43), cx + px(11), px(44), ROBEL)

    # Skull head
    head_cy = px(13)
    ell(d, cx, head_cy, px(12), px(12), BONE)
    ell(d, cx, head_cy + px(5), px(10), px(8), BONE)  # jaw
    # Skull cracks
    line(d, [(cx - px(4), head_cy - px(8)), (cx - px(2), head_cy - px(2))],
         fill=BONED, width=max(1, px(1)))
    line(d, [(cx + px(3), head_cy - px(7)), (cx + px(5), head_cy - px(1))],
         fill=BONED, width=max(1, px(1)))
    # Eye sockets (glowing purple)
    ell(d, cx - px(5), head_cy - px(2), px(4), px(4), (22, 16, 12))
    ell(d, cx + px(5), head_cy - px(2), px(4), px(4), (22, 16, 12))
    ell(d, cx - px(5), head_cy - px(2), px(3), px(3), EY)
    ell(d, cx + px(5), head_cy - px(2), px(3), px(3), EY)
    # Nose hole
    ell(d, cx, head_cy + px(3), px(2), px(2), BONEX)
    # Teeth (jaw)
    for i in range(-3, 4):
        ell(d, cx + px(i * 2), head_cy + px(9), px(1), px(2), BONE)
    # Dark robe hood
    poly(d, [(cx - px(12), head_cy - px(4)),
             (cx - px(10), head_cy - px(13)),
             (cx,          head_cy - px(15)),
             (cx + px(10), head_cy - px(13)),
             (cx + px(12), head_cy - px(4))], ROBED)
    poly(d, [(cx - px(9), head_cy - px(5)),
             (cx - px(7), head_cy - px(12)),
             (cx,         head_cy - px(14)),
             (cx + px(7), head_cy - px(12)),
             (cx + px(9), head_cy - px(5))], ROBE)

    # Skeletal arms
    ell(d, cx - px(14), px(27), px(3), px(8), BONE)   # left arm
    ell(d, cx + px(14), px(25), px(3), px(9), BONE)   # right arm (holding staff)
    # Bony hand (left)
    for i in range(3):
        ell(d, cx - px(13) + px(i*2), px(34), px(1), px(2), BONED)
    # Staff
    rect(d, cx + px(15), px(8),  cx + px(18), px(44), STAFF)
    # Magic orb on staff
    ell(d, cx + px(16), px(7), px(6), px(6), ORBM)
    ell(d, cx + px(16), px(7), px(4), px(4), ORBL)
    # Orb glow sparks
    for i in range(5):
        angle = math.radians(i * 72)
        sx = cx + px(16) + int(math.cos(angle) * px(7))
        sy = px(7)       + int(math.sin(angle) * px(7))
        ell(d, sx, sy, px(2), px(2), EY)

    save(img, "rpg_enemy_2.png", W, H, glow=(130, 60, 200))


# ════════════════════════════════════════════════════════════════════════════
# ENEMY SHIELDER  —  4×48×48  (added Iteration 4)
# ════════════════════════════════════════════════════════════════════════════

def gen_enemy_shielder():
    """Enemy Shielder — 4-frame walk: blue-silver plate armour + tower shield."""
    W, H = 48, 48

    # Colour palette — blue-silver plate
    PLATE  = (138, 172, 215)   # armour face
    PLATED = ( 92, 128, 165)   # armour shadow
    PLATEH = (205, 228, 248)   # armour highlight
    SHIELD = (108, 152, 200)   # shield face
    SHIELDD= ( 72, 112, 158)   # shield shadow
    SHIELDH= (225, 238, 255)   # shield highlight stripe
    HELM   = (128, 162, 205)   # helmet
    HELMH  = (202, 222, 245)   # helmet highlight
    SKN    = (235, 195, 155)   # skin (eyes/chin only)
    SKND   = (200, 160, 120)
    EYE    = ( 50,  80, 210)   # icy blue eyes
    LEGS   = ( 88, 120, 162)   # greaves
    LEGSD  = ( 60,  90, 132)
    BOOT   = ( 55,  70,  92)   # sabatons
    EMBL   = (210, 175,  55)   # gold emblem on shield

    # Walk-cycle offsets for legs and shield
    # (l_leg_dy, r_leg_dy, shield_dx, shield_dy, body_dy)
    frames_data = [
        ( 0,  0,  0,  0,  0),   # 0: stance
        (-3,  3, -1,  0, -1),   # 1: left foot forward
        ( 2,  2,  0,  2,  1),   # 2: midstep bob
        ( 3, -3,  1,  0, -1),   # 3: right foot forward
    ]

    for frame_idx, (ll_dy, rl_dy, sh_dx, sh_dy, body_dy) in enumerate(frames_data):
        img = new(W, H)
        d = ImageDraw.Draw(img)
        cx = W * S // 2
        body_cy = px(30) + px(body_dy)

        # ── Legs (greaves) ──────────────────────────────────────────────────
        # Right leg
        rl_y = body_cy + px(8) + px(rl_dy)
        rect(d, cx + px(2), body_cy + px(4), cx + px(8), rl_y, LEGS)
        rect(d, cx + px(2), body_cy + px(4), cx + px(5), rl_y, PLATED)  # inner shadow
        rect(d, cx + px(2), rl_y, cx + px(8), rl_y + px(4), BOOT)  # boot

        # Left leg (usually hidden by shield, just a hint)
        ll_y = body_cy + px(8) + px(ll_dy)
        rect(d, cx - px(8), body_cy + px(4), cx - px(2), ll_y, LEGSD)
        rect(d, cx - px(8), ll_y, cx - px(2), ll_y + px(4), BOOT)

        # ── Body (heavy plate torso) ────────────────────────────────────────
        poly(d, [(cx - px(9), body_cy - px(5)),
                 (cx + px(9), body_cy - px(5)),
                 (cx + px(10), body_cy + px(6)),
                 (cx - px(10), body_cy + px(6))], PLATE)
        # Chest highlight (left)
        poly(d, [(cx - px(9), body_cy - px(5)),
                 (cx - px(2), body_cy - px(5)),
                 (cx - px(2), body_cy + px(6)),
                 (cx - px(9), body_cy + px(6))], PLATEH)
        # Chest shadow (right)
        poly(d, [(cx + px(2), body_cy - px(5)),
                 (cx + px(9), body_cy - px(5)),
                 (cx + px(10), body_cy + px(6)),
                 (cx + px(2), body_cy + px(6))], PLATED)
        # Belt
        rect(d, cx - px(10), body_cy + px(5), cx + px(10), body_cy + px(8), PLATED)

        # ── Head (chibi, ~50% of sprite height) ────────────────────────────
        head_cy = px(13)
        # Helmet bowl
        ell(d, cx, head_cy, px(12), px(13), HELM)
        ell(d, cx - px(3), head_cy - px(2), px(8), px(8), HELMH)  # highlight
        # Visor slit (dark gap + eyes)
        rect(d, cx - px(9), head_cy + px(1), cx + px(9), head_cy + px(5), (28, 24, 20))
        # Eyes through visor
        ell(d, cx - px(5), head_cy + px(3), px(3), px(2), EYE)
        ell(d, cx + px(5), head_cy + px(3), px(3), px(2), EYE)
        ell(d, cx - px(5), head_cy + px(3), px(1), px(1), (210, 235, 255))  # glint
        ell(d, cx + px(5), head_cy + px(3), px(1), px(1), (210, 235, 255))
        # Chin guard (small)
        ell(d, cx, head_cy + px(10), px(7), px(5), PLATE)
        ell(d, cx - px(2), head_cy + px(10), px(4), px(3), PLATEH)
        # Helmet crest (ridge on top)
        poly(d, [(cx - px(1), head_cy - px(13)),
                 (cx + px(1), head_cy - px(13)),
                 (cx + px(2), head_cy - px(7)),
                 (cx - px(2), head_cy - px(7))], EMBL)

        # ── Shield (tower, left arm, dominant visual) ───────────────────────
        shx = cx - px(12) + px(sh_dx)
        shy = px(15) + px(sh_dy)
        # Shield body (tall kite shape)
        poly(d, [(shx,          shy),
                 (shx + px(10), shy),
                 (shx + px(12), shy + px(8)),
                 (shx + px(6),  shy + px(24)),
                 (shx - px(2),  shy + px(8))], SHIELD)
        # Shield highlight (left edge)
        poly(d, [(shx,          shy),
                 (shx + px(3),  shy),
                 (shx + px(4),  shy + px(8)),
                 (shx + px(1),  shy + px(20)),
                 (shx - px(2),  shy + px(8))], SHIELDH)
        # Shield shadow (right edge)
        poly(d, [(shx + px(7),  shy),
                 (shx + px(10), shy),
                 (shx + px(12), shy + px(8)),
                 (shx + px(6),  shy + px(24)),
                 (shx + px(5),  shy + px(8))], SHIELDD)
        # Gold cross emblem on shield
        rect(d, shx + px(3), shy + px(8), shx + px(8), shy + px(9), EMBL)   # horiz
        rect(d, shx + px(5), shy + px(4), shx + px(6), shy + px(16), EMBL)  # vert

        save(img, f"enemy_shielder_{frame_idx}.png", W, H)


# ════════════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("\n=== Garrison Chibi Sprite Generator — Iteration 1 ===\n")

    print("── Spell Hit VFX ──────────────────────────────────")
    gen_spell_hit_fire()
    gen_spell_hit_lightning()
    gen_spell_hit_ice()

    print("\n── RPG Décors ─────────────────────────────────────")
    gen_herb()
    gen_mushroom()
    gen_plant()

    print("\n── Ambient Creatures ──────────────────────────────")
    gen_ambient_bunny()
    gen_ambient_squirrel()
    gen_ambient_bird()
    gen_ambient_deer()
    gen_ambient_crow()

    print("\n── RPG Enemies ────────────────────────────────────")
    gen_rpg_enemy_goblin()
    gen_rpg_enemy_dark_elf()
    gen_rpg_enemy_skeleton_mage()

    print("\n── Enemy Shielder (Iteration 4) ───────────────────")
    gen_enemy_shielder()

    print(f"\n✓ All sprites written to: {OUT}\n")
