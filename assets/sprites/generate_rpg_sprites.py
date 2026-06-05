"""
Generate RPG character sprites, notice board, and castle icon for Garrison.
Output: assets/sprites/garrison/npc_*.png, notice_board.png, castle_icon.png
"""
from PIL import Image, ImageDraw
import os

OUT = os.path.join(os.path.dirname(__file__), "garrison")
os.makedirs(OUT, exist_ok=True)


def save(img, name):
    p = os.path.join(OUT, name)
    img.save(p)
    print(f"  {name} ({os.path.getsize(p)}B)")


# ── Palette helpers ──────────────────────────────────────────────────────────

def px(r, g, b, a=255):
    return (r, g, b, a)


# ── NPC sprites — 48×64 RGBA, top-down RPG style ────────────────────────────
# Each NPC has a clear silhouette and unique palette.
# Grid: head (rows 0-15), body/cape (16-44), legs (45-63).

def draw_npc_base(d, w, h, skin, shirt, pants):
    """Draw a generic humanoid body."""
    cx = w // 2
    # Shadow
    d.ellipse([cx - 14, h - 8, cx + 14, h - 1], fill=px(0, 0, 0, 60))
    # Legs
    d.rectangle([cx - 8, h - 20, cx - 3, h - 6], fill=pants)
    d.rectangle([cx + 3, h - 20, cx + 8, h - 6], fill=pants)
    # Shoes
    d.rectangle([cx - 9, h - 8, cx - 2, h - 4], fill=px(50, 35, 20))
    d.rectangle([cx + 2, h - 8, cx + 9, h - 4], fill=px(50, 35, 20))
    # Torso
    d.rectangle([cx - 11, h - 38, cx + 11, h - 20], fill=shirt)
    # Arms
    d.rectangle([cx - 16, h - 37, cx - 12, h - 22], fill=skin)
    d.rectangle([cx + 12, h - 37, cx + 16, h - 22], fill=skin)
    # Neck
    d.rectangle([cx - 3, h - 45, cx + 3, h - 38], fill=skin)
    # Head
    d.ellipse([cx - 9, h - 62, cx + 9, h - 44], fill=skin)
    # Eyes
    d.ellipse([cx - 6, h - 56, cx - 3, h - 53], fill=px(30, 20, 10))
    d.ellipse([cx + 3, h - 56, cx + 6, h - 53], fill=px(30, 20, 10))


def make_merchant():
    w, h = 48, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    skin = px(210, 175, 140)
    shirt = px(140, 90, 40)   # Rich brown tunic
    pants = px(90, 60, 25)
    draw_npc_base(d, w, h, skin, shirt, pants)
    cx = w // 2
    # Wide merchant hat (brim + cap)
    d.ellipse([cx - 13, h - 65, cx + 13, h - 57], fill=px(80, 50, 20))  # brim
    d.ellipse([cx - 8, h - 75, cx + 8, h - 57], fill=px(100, 65, 25))   # cap
    hat_band = px(200, 160, 60)
    d.rectangle([cx - 8, h - 63, cx + 8, h - 60], fill=hat_band)
    # Gold coin bag in right hand
    d.ellipse([cx + 12, h - 32, cx + 22, h - 20], fill=px(200, 170, 40))
    d.line([cx + 17, h - 34, cx + 17, h - 32], fill=px(150, 120, 30), width=2)
    # Apron
    d.rectangle([cx - 8, h - 36, cx + 8, h - 22], fill=px(220, 200, 160, 180))
    return img


def make_scout():
    w, h = 48, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    skin = px(195, 165, 130)
    shirt = px(55, 90, 45)    # Forest green
    pants = px(45, 70, 35)
    draw_npc_base(d, w, h, skin, shirt, pants)
    cx = w // 2
    # Hood — pointed top
    hood_pts = [(cx, h - 78), (cx - 12, h - 60), (cx + 12, h - 60)]
    d.polygon(hood_pts, fill=px(35, 65, 30))
    d.ellipse([cx - 10, h - 64, cx + 10, h - 52], fill=px(35, 65, 30))
    # Face remains visible (skin shows through hood front)
    # Bow — left side
    bow_col = px(100, 70, 35)
    d.arc([cx - 26, h - 50, cx - 14, h - 22], 30, 330, fill=bow_col, width=3)
    d.line([cx - 20, h - 50, cx - 20, h - 22], fill=px(200, 200, 190), width=1)
    # Arrow quiver on back (right side)
    d.rectangle([cx + 12, h - 48, cx + 18, h - 26], fill=px(100, 70, 40))
    d.line([cx + 13, h - 48, cx + 13, h - 30], fill=px(200, 200, 200), width=1)
    d.line([cx + 16, h - 50, cx + 16, h - 28], fill=px(200, 200, 200), width=1)
    return img


def make_sage():
    w, h = 48, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    skin = px(230, 205, 180)
    shirt = px(120, 90, 170)  # Purple robe
    pants = px(90, 65, 130)
    draw_npc_base(d, w, h, skin, shirt, pants)
    cx = w // 2
    # Long robe overrides legs
    d.rectangle([cx - 11, h - 38, cx + 11, h - 5], fill=px(100, 75, 150))
    robe_detail = px(150, 120, 200)
    d.line([cx - 11, h - 38, cx - 11, h - 5], fill=robe_detail, width=2)
    d.line([cx + 11, h - 38, cx + 11, h - 5], fill=robe_detail, width=2)
    # Tall pointed wizard hat
    hat_pts = [(cx, h - 88), (cx - 11, h - 62), (cx + 11, h - 62)]
    d.polygon(hat_pts, fill=px(80, 55, 120))
    d.ellipse([cx - 14, h - 65, cx + 14, h - 60], fill=px(70, 45, 110))
    # Stars on hat
    for sx, sy in [(cx - 3, h - 78), (cx + 4, h - 72)]:
        for dx, dy in [(-2, 0), (2, 0), (0, -2), (0, 2)]:
            d.point((sx + dx, sy + dy), fill=px(255, 235, 60))
        d.point((sx, sy), fill=px(255, 240, 100))
    # Staff in right hand
    d.line([cx + 15, h - 50, cx + 15, h - 6], fill=px(130, 100, 60), width=3)
    d.ellipse([cx + 11, h - 56, cx + 19, h - 48], fill=px(100, 200, 240, 220))
    return img


def make_bard():
    w, h = 48, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    skin = px(205, 170, 130)
    shirt = px(200, 80, 60)   # Bright red/orange
    pants = px(60, 100, 170)  # Blue pants
    draw_npc_base(d, w, h, skin, shirt, pants)
    cx = w // 2
    # Jester/bard hat — two-pointed
    d.rectangle([cx - 11, h - 65, cx + 11, h - 60], fill=px(180, 60, 50))
    # Left point
    pts_l = [(cx - 11, h - 65), (cx - 16, h - 78), (cx, h - 65)]
    d.polygon(pts_l, fill=px(180, 60, 50))
    d.ellipse([cx - 18, h - 81, cx - 12, h - 75], fill=px(255, 215, 0))
    # Right point
    pts_r = [(cx, h - 65), (cx + 16, h - 78), (cx + 11, h - 65)]
    d.polygon(pts_r, fill=px(60, 130, 200))
    d.ellipse([cx + 12, h - 81, cx + 18, h - 75], fill=px(255, 215, 0))
    # Lute — classic body shape
    lute_col = px(160, 110, 50)
    d.ellipse([cx + 8, h - 42, cx + 22, h - 26], fill=lute_col)    # body
    d.rectangle([cx + 13, h - 52, cx + 17, h - 40], fill=lute_col) # neck
    d.ellipse([cx + 12, h - 56, cx + 18, h - 50], fill=px(140, 95, 40))  # head
    # Strings
    for i in range(3):
        sx = cx + 14 + i
        d.line([sx, h - 52, sx, h - 26], fill=px(240, 230, 210), width=1)
    # Collar ruffle
    d.ellipse([cx - 13, h - 43, cx + 13, h - 36], fill=px(240, 235, 210, 200))
    return img


def make_healer():
    w, h = 48, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    skin = px(215, 185, 155)
    shirt = px(230, 225, 215)  # White/cream robes
    pants = px(200, 195, 185)
    draw_npc_base(d, w, h, skin, shirt, pants)
    cx = w // 2
    # Full white robe
    d.rectangle([cx - 11, h - 38, cx + 11, h - 5], fill=px(225, 220, 210))
    d.rectangle([cx - 16, h - 37, cx - 12, h - 22], fill=px(225, 220, 210))
    d.rectangle([cx + 12, h - 37, cx + 16, h - 22], fill=px(225, 220, 210))
    # Red cross on chest
    cross_col = px(200, 40, 40)
    d.rectangle([cx - 2, h - 35, cx + 2, h - 25], fill=cross_col)
    d.rectangle([cx - 6, h - 32, cx + 6, h - 28], fill=cross_col)
    # White healer hood
    d.ellipse([cx - 12, h - 64, cx + 12, h - 44], fill=px(235, 230, 220))
    # Hood fringe
    d.rectangle([cx - 12, h - 58, cx + 12, h - 52], fill=px(220, 215, 205))
    # Healing staff with heart
    d.line([cx - 14, h - 50, cx - 14, h - 6], fill=px(180, 150, 100), width=3)
    # Heart
    heart_col = px(220, 60, 80)
    d.ellipse([cx - 19, h - 57, cx - 15, h - 53], fill=heart_col)
    d.ellipse([cx - 14, h - 57, cx - 10, h - 53], fill=heart_col)
    pts_h = [(cx - 20, h - 55), (cx - 14, h - 50), (cx - 9, h - 55)]
    d.polygon(pts_h, fill=heart_col)
    return img


# ── Notice Board sprite — 96×80 RGBA ────────────────────────────────────────
def make_notice_board():
    """Wooden notice board with 3 pinned parchment scrolls."""
    w, h = 96, 80
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    wood = px(120, 80, 40)
    wood_dark = px(90, 55, 25)
    wood_light = px(155, 110, 60)

    # Post
    d.rectangle([43, 55, 53, h - 1], fill=wood_dark)
    # Cross-beam
    d.rectangle([8, 53, 88, 60], fill=wood_dark)
    # Main board frame
    d.rectangle([6, 4, 90, 55], fill=wood)
    # Board inner (lighter)
    d.rectangle([10, 8, 86, 52], fill=wood_light)
    # Board grain lines
    for gy in [16, 26, 36, 46]:
        d.line([10, gy, 86, gy], fill=px(140, 95, 50, 80), width=1)
    # Corner nails
    for nx, ny in [(12, 10), (84, 10), (12, 50), (84, 50)]:
        d.ellipse([nx - 2, ny - 2, nx + 2, ny + 2], fill=px(70, 60, 55))

    # 3 parchment cards
    parchment = px(245, 230, 185)
    parchment_shadow = px(220, 200, 150)
    pin_col = px(180, 50, 40)

    card_rects = [(13, 11, 39, 49), (38, 11, 64, 49), (63, 11, 89, 49)]
    for i, (x1, y1, x2, y2) in enumerate(card_rects):
        # Card shadow
        d.rectangle([x1 + 2, y1 + 2, x2 + 2, y2 + 2], fill=parchment_shadow)
        # Card body
        d.rectangle([x1, y1, x2, y2], fill=parchment)
        # Lines of "text" (3 wavy lines per card)
        lx1, lx2 = x1 + 3, x2 - 3
        for li, ly in enumerate([y1 + 8, y1 + 16, y1 + 24, y1 + 32]):
            line_len = lx2 - lx1 - (li * 3 % 6)
            line_col = px(100, 80, 50, 160)
            d.line([lx1, ly, lx1 + line_len, ly], fill=line_col, width=1)
        # Difficulty color badge (easy=green, medium=orange, hard=red)
        badge_cols = [px(60, 160, 60), px(210, 120, 30), px(200, 45, 45)]
        d.rectangle([x1 + 3, y2 - 9, x2 - 3, y2 - 2], fill=badge_cols[i])
        # Thumbtack pin
        px_pin = (x1 + x2) // 2
        d.ellipse([px_pin - 3, y1 - 2, px_pin + 3, y1 + 4], fill=pin_col)
        d.ellipse([px_pin - 1, y1 - 1, px_pin + 1, y1 + 1], fill=px(240, 180, 180))

    return img


# ── Castle icon — 40×40 RGBA (for return button) ────────────────────────────
def make_castle_icon():
    w, h = 40, 40
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stone = px(155, 140, 125)
    stone_dark = px(110, 100, 90)
    stone_light = px(185, 172, 155)
    # Shadow
    d.ellipse([4, 33, 36, 39], fill=px(0, 0, 0, 70))
    # Main tower body
    d.rectangle([12, 18, 28, 35], fill=stone)
    # Crenellations (merlons) — 3 on top of tower
    for tx in [12, 17, 22]:
        d.rectangle([tx, 12, tx + 4, 18], fill=stone)
    # Side walls
    d.rectangle([4, 24, 12, 35], fill=stone_dark)
    d.rectangle([28, 24, 36, 35], fill=stone_dark)
    # Side crenellations (2 per side)
    for tx in [4, 9]:
        d.rectangle([tx, 19, tx + 3, 24], fill=stone_dark)
    for tx in [28, 33]:
        d.rectangle([tx, 19, tx + 3, 24], fill=stone_dark)
    # Gate arch
    d.rectangle([17, 25, 23, 35], fill=px(40, 30, 20))
    d.ellipse([17, 22, 23, 28], fill=px(40, 30, 20))
    # Gate bars
    d.line([19, 25, 19, 34], fill=px(70, 55, 40), width=1)
    d.line([21, 25, 21, 34], fill=px(70, 55, 40), width=1)
    # Window on tower
    d.rectangle([18, 19, 22, 23], fill=px(50, 80, 150, 200))
    # Flag
    d.line([20, 3, 20, 13], fill=px(90, 65, 40), width=1)
    flag_pts = [(20, 3), (29, 6), (20, 9)]
    d.polygon(flag_pts, fill=px(200, 40, 40))
    # Stone texture hints
    for sx, sy in [(14, 21), (24, 21), (14, 28), (24, 28)]:
        d.rectangle([sx, sy, sx + 3, sy + 2], fill=stone_light)
    return img


# ── Dungeon entrance sprite — 64×64 RGBA ────────────────────────────────────
def make_dungeon_entrance():
    w, h = 64, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stone = px(100, 90, 80)
    stone_d = px(65, 58, 50)
    # Ground/shadow
    d.ellipse([8, 54, 56, 63], fill=px(0, 0, 0, 100))
    # Arch stones (6 blocks)
    arch_pts = [
        [16, 28, 23, 36], [23, 20, 30, 28],
        [30, 16, 36, 22], [36, 16, 42, 22],
        [42, 20, 49, 28], [49, 28, 56, 36],
    ]
    for r in arch_pts:
        d.rectangle(r, fill=stone)
        d.rectangle([r[0] + 1, r[1] + 1, r[2] - 1, r[3] - 1], fill=stone_d)
    # Left pillar
    d.rectangle([14, 28, 22, 58], fill=stone)
    d.rectangle([14, 28, 16, 58], fill=stone_d)
    # Right pillar
    d.rectangle([50, 28, 58, 58], fill=stone)
    d.rectangle([56, 28, 58, 58], fill=stone_d)
    # Dark interior
    d.rectangle([22, 22, 50, 58], fill=px(15, 10, 20))
    d.ellipse([22, 16, 50, 30], fill=px(15, 10, 20))
    # Glowing runes on arch
    rune_col = px(60, 180, 255, 200)
    for rx, ry in [(20, 32), (26, 24), (38, 22), (46, 24), (52, 32)]:
        d.point((rx, ry), fill=rune_col)
        d.point((rx, ry - 2), fill=rune_col)
        d.point((rx - 1, ry + 1), fill=rune_col)
        d.point((rx + 1, ry + 1), fill=rune_col)
    # Torch light on sides
    for tx, ty in [(17, 38), (53, 38)]:
        d.ellipse([tx - 3, ty - 4, tx + 3, ty + 4], fill=px(255, 180, 50, 120))
        d.ellipse([tx - 2, ty - 3, tx + 2, ty + 3], fill=px(255, 220, 100))
    # "?" question mark hint
    d.text = None  # No font available — skip text
    return img


# ── Mount sprite — 80×56 RGBA (hero riding a horse variant) ─────────────────
def make_mount_sprite():
    """Simple horse silhouette for mount visual."""
    w, h = 80, 56
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    horse_col = px(150, 100, 55)
    horse_d = px(120, 78, 40)
    horse_l = px(180, 130, 75)
    mane = px(90, 55, 25)

    # Shadow
    d.ellipse([10, 48, 70, 55], fill=px(0, 0, 0, 80))
    # Tail
    tail_pts = [(18, 20), (10, 14), (8, 26), (14, 30), (18, 22)]
    d.polygon(tail_pts, fill=horse_d)
    # Body
    d.ellipse([16, 20, 60, 44], fill=horse_col)
    # Head & neck
    d.rectangle([54, 18, 68, 30], fill=horse_col)  # neck
    d.ellipse([60, 12, 78, 28], fill=horse_col)    # head
    # Snout
    d.ellipse([72, 18, 80, 26], fill=horse_d)
    # Eye
    d.ellipse([68, 14, 72, 18], fill=px(30, 20, 10))
    # Mane
    for mx, my in [(60, 18), (58, 22), (56, 20)]:
        d.ellipse([mx - 2, my - 2, mx + 4, my + 4], fill=mane)
    # Ears
    d.polygon([(62, 12), (64, 6), (68, 12)], fill=horse_d)
    d.polygon([(66, 12), (68, 7), (70, 12)], fill=horse_d)
    # Legs — 4 with slight offset for motion
    leg_col = horse_d
    legs = [(22, 40, 24, 54), (30, 40, 32, 52), (44, 40, 46, 54), (52, 38, 54, 52)]
    for lx1, ly1, lx2, ly2 in legs:
        d.rectangle([lx1, ly1, lx2, ly2], fill=leg_col)
        d.rectangle([lx1 - 1, ly2 - 4, lx2 + 1, ly2], fill=px(60, 45, 30))  # hoof
    # Saddle area (rider placeholder)
    d.ellipse([30, 14, 50, 30], fill=px(100, 65, 30, 200))  # saddle blanket
    d.rectangle([32, 22, 48, 26], fill=px(80, 50, 20))      # girth
    return img


# ── Status effect overlays — 32×32 RGBA icons ───────────────────────────────

def make_status_burning():
    """Burning status: orange/red flame icon."""
    w, h = 32, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Outer glow
    d.ellipse([2, 8, 30, 30], fill=px(200, 60, 0, 80))
    # Flame body
    pts = [(16, 2), (8, 14), (6, 24), (16, 30), (26, 24), (24, 14)]
    d.polygon(pts, fill=px(230, 100, 20))
    # Inner flame
    pts2 = [(16, 8), (10, 18), (12, 26), (16, 28), (20, 26), (22, 18)]
    d.polygon(pts2, fill=px(255, 200, 50))
    # Core
    d.ellipse([13, 20, 19, 28], fill=px(255, 240, 150))
    return img


def make_status_stunned():
    """Stunned/lightning status: yellow lightning bolt."""
    w, h = 32, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Glow
    d.ellipse([2, 2, 30, 30], fill=px(200, 200, 0, 70))
    # Lightning bolt
    bolt = [(18, 2), (10, 16), (16, 16), (12, 30), (22, 14), (16, 14)]
    d.polygon(bolt, fill=px(255, 240, 0))
    # Highlight
    bolt2 = [(17, 4), (12, 15), (17, 15), (14, 26)]
    d.polygon(bolt2, fill=px(255, 255, 180))
    return img


def make_status_frozen():
    """Frozen/slowed status: blue snowflake."""
    w, h = 32, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = 16, 16
    # Glow
    d.ellipse([2, 2, 30, 30], fill=px(100, 180, 255, 80))
    # Snowflake — 6 arms
    for angle_deg in [0, 60, 120, 180, 240, 300]:
        import math
        a = math.radians(angle_deg)
        ex = int(cx + 12 * math.cos(a))
        ey = int(cy + 12 * math.sin(a))
        d.line([cx, cy, ex, ey], fill=px(150, 220, 255), width=3)
        # Barbs
        for t in [0.4, 0.7]:
            bx = int(cx + 12 * t * math.cos(a))
            by = int(cy + 12 * t * math.sin(a))
            for da in [60, -60]:
                ba = math.radians(angle_deg + da)
                bbx = int(bx + 5 * math.cos(ba))
                bby = int(by + 5 * math.sin(ba))
                d.line([bx, by, bbx, bby], fill=px(180, 235, 255), width=2)
    # Center
    d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=px(220, 245, 255))
    return img


# ── Spell upgrade icon badges — 24×24 RGBA ──────────────────────────────────

def make_spell_upgrade_badge(level: int, color_rgb: tuple):
    """Level badge (I / II / III) for spell upgrades."""
    w, h = 24, 24
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r, g, b = color_rgb
    # Circle bg
    d.ellipse([1, 1, 22, 22], fill=px(r, g, b))
    d.ellipse([2, 2, 21, 21], fill=px(min(r + 40, 255), min(g + 40, 255), min(b + 40, 255)))
    # Roman numeral dots (I=1, II=2, III=3)
    xc = 12
    lw = 2
    if level == 1:
        d.rectangle([xc - 1, 7, xc + 1, 17], fill=px(255, 255, 255))
    elif level == 2:
        d.rectangle([xc - 4, 7, xc - 2, 17], fill=px(255, 255, 255))
        d.rectangle([xc + 2, 7, xc + 4, 17], fill=px(255, 255, 255))
    elif level == 3:
        for bx in [xc - 5, xc - 1, xc + 3]:
            d.rectangle([bx, 7, bx + lw, 17], fill=px(255, 255, 255))
    return img


# ── Mount scroll item sprite — 32×32 ────────────────────────────────────────
def make_mount_scroll():
    w, h = 32, 32
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    parch = px(235, 215, 170)
    roll_col = px(180, 140, 90)
    # Scroll body
    d.rectangle([6, 6, 26, 26], fill=parch)
    # Roll ends
    d.ellipse([4, 4, 10, 12], fill=roll_col)
    d.ellipse([4, 20, 10, 28], fill=roll_col)
    d.ellipse([22, 4, 28, 12], fill=roll_col)
    d.ellipse([22, 20, 28, 28], fill=roll_col)
    # Horse silhouette on scroll
    horse_pts = [(12, 20), (10, 14), (12, 10), (16, 8), (20, 10), (22, 14),
                 (20, 20), (19, 24), (21, 24), (19, 22), (17, 24), (15, 24),
                 (13, 22), (11, 24), (13, 24)]
    d.polygon(horse_pts, fill=px(100, 70, 40))
    # Ribbon
    d.rectangle([11, 15, 21, 17], fill=px(180, 40, 40))
    return img


if __name__ == "__main__":
    print("Generating RPG sprites for Garrison...")
    save(make_merchant(),       "npc_merchant.png")
    save(make_scout(),          "npc_scout.png")
    save(make_sage(),           "npc_sage.png")
    save(make_bard(),           "npc_bard.png")
    save(make_healer(),         "npc_healer.png")
    save(make_notice_board(),   "notice_board.png")
    save(make_castle_icon(),    "castle_icon.png")
    save(make_dungeon_entrance(),"dungeon_entrance.png")
    save(make_mount_sprite(),   "mount_horse.png")
    save(make_status_burning(), "status_burning.png")
    save(make_status_stunned(), "status_stunned.png")
    save(make_status_frozen(),  "status_frozen.png")
    save(make_spell_upgrade_badge(1, (200, 60, 40)),  "spell_upgrade_1.png")
    save(make_spell_upgrade_badge(2, (200, 140, 30)), "spell_upgrade_2.png")
    save(make_spell_upgrade_badge(3, (80, 60, 200)),  "spell_upgrade_3.png")
    save(make_mount_scroll(),   "mount_scroll.png")
    print("Done.")
