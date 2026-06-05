#!/usr/bin/env python3
"""
Generate improved Garrison sprites:
  - Wild Rift-style joystick (base + knob)
  - Type-distinct enemy sprites (infantry / archer / cavalier / healer) x4 frames each
  - Spell icons (fire / lightning / ice)

Run: python3 assets/sprites/generate_improved_sprites.py
Output: assets/sprites/garrison/
"""

from PIL import Image, ImageDraw, ImageFilter
import math, os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "garrison")
os.makedirs(OUT, exist_ok=True)


# ── Helpers ───────────────────────────────────────────────────────────────────

def H(h, a=255):
    """Hex #RRGGBB -> RGBA tuple."""
    r = int(h[1:3], 16); g = int(h[3:5], 16); b = int(h[5:7], 16)
    return (r, g, b, a)


def new_img(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def save(img, path):
    img.save(path)
    print(f"  {os.path.relpath(path)}")


def outlined_rect(draw, x, y, w, h, fill, ol=(0, 0, 0, 255), ow=2):
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=fill)
    draw.rectangle([x, y, x + w - 1, y + h - 1], outline=ol, width=ow)


def outlined_ellipse(draw, x, y, w, h, fill, ol=(0, 0, 0, 255), ow=2):
    draw.ellipse([x, y, x + w - 1, y + h - 1], fill=fill)
    draw.ellipse([x, y, x + w - 1, y + h - 1], outline=ol, width=ow)


def outlined_polygon(draw, pts, fill, ol=(0, 0, 0, 255), ow=2):
    draw.polygon(pts, fill=fill)
    n = len(pts)
    for i in range(n):
        p1 = pts[i]; p2 = pts[(i + 1) % n]
        draw.line([p1, p2], fill=ol, width=ow)


# ── Joystick ──────────────────────────────────────────────────────────────────

def make_joystick_base():
    """
    Wild Rift style: large translucent dark circle with thin white ring border.
    180x180 RGBA.
    """
    img = new_img(180, 180)
    draw = ImageDraw.Draw(img)
    cx, cy, R = 90, 90, 84

    # Outermost subtle glow ring
    draw.ellipse([cx - R - 4, cy - R - 4, cx + R + 4, cy + R + 4],
                 fill=(255, 255, 255, 20))

    # Dark semi-transparent fill — multiple concentric circles for gradient feel
    for i in range(R, 0, -1):
        alpha = int(165 * (i / R))  # centre darker
        draw.ellipse([cx - i, cy - i, cx + i, cy + i],
                     fill=(15, 20, 30, alpha))

    # White border ring (2px)
    draw.ellipse([cx - R, cy - R, cx + R, cy + R],
                 outline=(255, 255, 255, 120), width=2)

    # Inner dashed cross lines (subtle directional guides)
    line_col = (255, 255, 255, 30)
    draw.line([cx, cy - R + 10, cx, cy - 8], fill=line_col, width=1)
    draw.line([cx, cy + 8, cx, cy + R - 10], fill=line_col, width=1)
    draw.line([cx - R + 10, cy, cx - 8, cy], fill=line_col, width=1)
    draw.line([cx + 8, cy, cx + R - 10, cy], fill=line_col, width=1)

    return img


def make_joystick_knob():
    """
    Wild Rift style: bright circular knob with radial gradient (centre bright → edge dim).
    72x72 RGBA.
    """
    img = new_img(72, 72)
    cx, cy, R = 36, 36, 30

    # Build gradient circle manually
    px = img.load()
    for y in range(72):
        for x in range(72):
            dx, dy = x - cx, y - cy
            dist = math.sqrt(dx * dx + dy * dy)
            if dist <= R:
                # Radial gradient: white at center → steel blue at edge
                t = dist / R
                r = int(220 - t * 90)    # 220 → 130
                g = int(230 - t * 100)   # 230 → 130
                b = int(255 - t * 60)    # 255 → 195
                a = 230
                px[x, y] = (r, g, b, a)

    draw = ImageDraw.Draw(img)
    # White border ring
    draw.ellipse([cx - R, cy - R, cx + R, cy + R],
                 outline=(255, 255, 255, 200), width=2)
    # Inner shine highlight — top-left arc
    draw.arc([cx - R + 8, cy - R + 4, cx - 2, cy + 4],
             start=-60, end=60, fill=(255, 255, 255, 180), width=3)

    return img


# ── Enemy sprites ─────────────────────────────────────────────────────────────
#
# Canvas: 80x88 RGBA (matches existing enemy_N.png dimensions)
# 4 walk frames per type: frame=0 neutral, 1 step-R, 2 neutral-alt, 3 step-L
# Leg offsets for walk cycle: dy_body=[0,-3,0,+2], dx_l=[-4,0,4,0], dx_r=[4,0,-4,0]
#
# All types are front-facing top-down (enemies approach from the right of screen).

WALK_BODY_DY = [0, -3, 0, 2]   # body vertical bob per frame
WALK_LEG_LX  = [-4, 0,  4, 0]  # left leg horizontal offset
WALK_LEG_RX  = [ 4, 0, -4, 0]  # right leg horizontal offset

W, H_SPRITE = 80, 88


def draw_infantry(draw, frame):
    """
    INFANTRY: stocky armored footsoldier.
    Colors: steel grey armor, blue tabard, round silver helmet.
    Silhouette: wide (shield), squat.
    """
    dy = WALK_BODY_DY[frame]
    cx = 40

    # --- Legs (walk bob) ---
    leg_y = 62 + dy
    leg_w, leg_h = 10, 16
    lx = cx - 14 + WALK_LEG_LX[frame]
    rx = cx + 4  + WALK_LEG_RX[frame]
    outlined_rect(draw, lx,     leg_y, leg_w, leg_h, H("#546E7A"))  # left leg grey
    outlined_rect(draw, rx,     leg_y, leg_w, leg_h, H("#546E7A"))  # right leg grey
    # Boots
    outlined_rect(draw, lx - 1, leg_y + leg_h - 5, leg_w + 2, 6, H("#37474F"))
    outlined_rect(draw, rx - 1, leg_y + leg_h - 5, leg_w + 2, 6, H("#37474F"))

    # --- Body / tabard ---
    body_x, body_y = cx - 18, 36 + dy
    body_w, body_h = 36, 28
    outlined_rect(draw, body_x, body_y, body_w, body_h, H("#78909C"))     # steel plate
    # Blue tabard stripe down centre
    draw.rectangle([cx - 5, body_y + 2, cx + 5, body_y + body_h - 2], fill=H("#1565C0"))

    # --- Shield (left side protrusion) ---
    shield_pts = [
        (cx - 26, body_y + 4),
        (cx - 14, body_y + 4),
        (cx - 14, body_y + body_h + 2),
        (cx - 22, body_y + body_h + 6),
        (cx - 28, body_y + body_h + 2),
    ]
    outlined_polygon(draw, shield_pts, H("#1565C0"))
    # Shield boss (center rivet)
    draw.ellipse([cx - 22, body_y + 14, cx - 16, body_y + 20], fill=H("#CFD8DC"))

    # --- Sword arm (right) ---
    sword_x = cx + 16
    outlined_rect(draw, sword_x, body_y + 6, 8, 20, H("#78909C"))  # arm
    # Sword blade pointing upward
    sword_pts = [
        (sword_x + 2, body_y - 4),
        (sword_x + 6, body_y - 4),
        (sword_x + 6, body_y + 8),
        (sword_x + 2, body_y + 8),
    ]
    outlined_polygon(draw, sword_pts, H("#E0E0E0"))
    # Crossguard
    draw.rectangle([sword_x - 1, body_y + 6, sword_x + 9, body_y + 9], fill=H("#9E9E9E"))

    # --- Head + helmet ---
    head_y = 16 + dy
    outlined_ellipse(draw, cx - 14, head_y, 28, 26, H("#FFCC80"))  # face skin
    # Helmet (round top + cheek guards)
    outlined_ellipse(draw, cx - 14, head_y - 4, 28, 18, H("#B0BEC5"))   # helmet dome
    outlined_rect(draw, cx - 14, head_y + 4, 8, 12, H("#90A4AE"))        # left cheekguard
    outlined_rect(draw, cx + 6, head_y + 4, 8, 12, H("#90A4AE"))         # right cheekguard
    # Eye slit
    draw.rectangle([cx - 8, head_y + 8, cx + 8, head_y + 10], fill=(0, 0, 0, 180))

    # --- Shoulder pauldrons ---
    outlined_ellipse(draw, cx - 20, body_y - 2, 14, 10, H("#90A4AE"))
    outlined_ellipse(draw, cx + 6, body_y - 2, 14, 10, H("#90A4AE"))


def draw_archer_enemy(draw, frame):
    """
    ARCHER ENEMY: quick, lightly armored, carries bow.
    Colors: auburn leather, dark hood, olive green cloak.
    Silhouette: taller, thinner, bow visible at side.
    """
    dy = WALK_BODY_DY[frame]
    cx = 40

    # --- Legs ---
    leg_y = 62 + dy
    lx = cx - 10 + WALK_LEG_LX[frame]
    rx = cx + 2  + WALK_LEG_RX[frame]
    outlined_rect(draw, lx, leg_y, 8, 18, H("#6D4C41"))  # leather leggings
    outlined_rect(draw, rx, leg_y, 8, 18, H("#6D4C41"))
    outlined_rect(draw, lx - 1, leg_y + 13, 10, 6, H("#4E342E"))  # boots
    outlined_rect(draw, rx - 1, leg_y + 13, 10, 6, H("#4E342E"))

    # --- Cloak / body ---
    body_x, body_y = cx - 14, 34 + dy
    outlined_rect(draw, body_x, body_y, 28, 30, H("#558B2F"))      # olive cloak
    # Leather chest over cloak
    outlined_rect(draw, body_x + 4, body_y + 2, 20, 20, H("#8D6E63"))

    # --- Bow (left side) ---
    bow_x = cx - 24
    bow_pts = [
        (bow_x + 2, body_y - 4),
        (bow_x + 6, body_y + 14),
        (bow_x + 4, body_y + 14),
        (bow_x, body_y - 4),
    ]
    # Bow arc
    draw.arc([bow_x - 2, body_y - 4, bow_x + 10, body_y + 26],
             start=-30, end=210, fill=H("#A1887F"), width=3)
    # Bowstring
    draw.line([(bow_x + 4, body_y - 2), (bow_x + 4, body_y + 24)],
              fill=H("#FFF9C4", 200), width=1)

    # --- Drawing hand (right arm extended) ---
    arm_y = body_y + 6
    draw.line([(cx + 14, arm_y + 4), (cx + 24, arm_y - 2)],
              fill=H("#6D4C41"), width=5)
    # Arrow nocked
    draw.line([(bow_x + 4, arm_y), (cx + 24, arm_y - 2)],
              fill=H("#FFF9C4"), width=1)

    # --- Quiver (right side, back) ---
    outlined_rect(draw, cx + 14, body_y + 4, 8, 18, H("#5D4037"))
    for qi in range(3):
        draw.line([(cx + 15 + qi * 2, body_y + 2), (cx + 15 + qi * 2, body_y + 6)],
                  fill=H("#F57F17"), width=1)

    # --- Head + hood ---
    head_y = 14 + dy
    outlined_ellipse(draw, cx - 11, head_y + 2, 22, 22, H("#FFCC80"))   # face
    # Dark hood
    draw.ellipse([cx - 14, head_y - 2, cx + 14, head_y + 16], fill=H("#33691E"))
    # Hood outline
    draw.ellipse([cx - 14, head_y - 2, cx + 14, head_y + 16], outline=(0,0,0,255), width=2)
    # Eyes
    draw.ellipse([cx - 6, head_y + 8, cx - 2, head_y + 12], fill=(0, 0, 0, 220))
    draw.ellipse([cx + 2, head_y + 8, cx + 6, head_y + 12], fill=(0, 0, 0, 220))


def draw_cavalier_enemy(draw, frame):
    """
    CAVALIER ENEMY: heavy cavalry — widest silhouette, horse body low.
    Colors: chestnut horse, gold armor, red plume.
    Silhouette: wide + tall, distinct horse head right side.
    """
    dy = WALK_BODY_DY[frame] // 2  # subtler bob for mounted
    cx = 42

    # --- Horse body (main mass) ---
    horse_pts = [
        (cx - 28, 56 + dy),  # back top
        (cx + 28, 52 + dy),  # front top
        (cx + 30, 72 + dy),  # front bottom
        (cx - 24, 76 + dy),  # back bottom
    ]
    outlined_polygon(draw, horse_pts, H("#6D4C41"))

    # --- Horse legs (4 legs, slight walk anim) ---
    ll = WALK_LEG_LX[frame] * 2
    rl = WALK_LEG_RX[frame] * 2
    # Back legs
    outlined_rect(draw, cx - 24 + ll, 74 + dy, 8, 14, H("#5D4037"))
    outlined_rect(draw, cx - 10 + rl, 74 + dy, 8, 14, H("#5D4037"))
    # Front legs
    outlined_rect(draw, cx + 6 + ll, 72 + dy, 8, 14, H("#5D4037"))
    outlined_rect(draw, cx + 18 + rl, 72 + dy, 8, 14, H("#5D4037"))
    # Hooves
    for hx in [cx - 24 + ll, cx - 10 + rl, cx + 6 + ll, cx + 18 + rl]:
        outlined_rect(draw, hx - 1, 86 + dy, 10, 4, H("#37474F"))

    # --- Horse neck + head ---
    neck_pts = [(cx + 18, 52 + dy), (cx + 28, 52 + dy), (cx + 32, 40 + dy), (cx + 22, 38 + dy)]
    outlined_polygon(draw, neck_pts, H("#6D4C41"))
    # Head
    outlined_ellipse(draw, cx + 20, 28 + dy, 20, 16, H("#795548"))
    # Eye
    draw.ellipse([cx + 26, 32 + dy, cx + 30, 36 + dy], fill=(0, 0, 0, 220))
    # Nostril
    draw.ellipse([cx + 34, 38 + dy, cx + 38, 40 + dy], fill=H("#5D4037"))
    # Mane
    draw.polygon([(cx + 18, 34 + dy), (cx + 24, 28 + dy), (cx + 28, 36 + dy),
                  (cx + 22, 32 + dy), (cx + 26, 40 + dy)], fill=H("#33261A"))

    # --- Tail ---
    tail_pts = [(cx - 26, 58 + dy), (cx - 38, 64 + dy), (cx - 32, 78 + dy)]
    draw.polygon(tail_pts, fill=H("#33261A"))

    # --- Rider body (smaller, atop horse) ---
    rider_y = 30 + dy
    rider_cx = cx - 4
    # Armored torso
    outlined_rect(draw, rider_cx - 12, rider_y, 24, 22, H("#F57F17"))   # gold armor
    # Cape behind
    cape_pts = [(rider_cx - 10, rider_y + 4), (rider_cx - 18, rider_y + 26),
                (rider_cx + 2, rider_y + 26), (rider_cx + 4, rider_y + 4)]
    draw.polygon(cape_pts, fill=H("#B71C1C"))

    # --- Rider arms + lance ---
    # Lance (right side, angled forward)
    lance_base = (rider_cx + 12, rider_y + 10)
    lance_tip  = (cx + 38, rider_y - 6)
    draw.line([lance_base, lance_tip], fill=H("#8D6E63"), width=4)
    # Lance tip
    lance_tip_pts = [(cx + 34, rider_y - 12), (cx + 40, rider_y - 4), (cx + 36, rider_y - 2)]
    draw.polygon(lance_tip_pts, fill=H("#E0E0E0"))

    # --- Rider head + helmet ---
    head_y = 14 + dy
    outlined_ellipse(draw, rider_cx - 10, head_y, 20, 18, H("#FFCC80"))   # face
    # Helmet
    draw.ellipse([rider_cx - 11, head_y - 4, rider_cx + 9, head_y + 10], fill=H("#F57F17"))
    draw.ellipse([rider_cx - 11, head_y - 4, rider_cx + 9, head_y + 10], outline=(0,0,0,255), width=2)
    # Visor slit
    draw.rectangle([rider_cx - 7, head_y + 4, rider_cx + 7, head_y + 6], fill=(0,0,0,200))
    # Red plume on helmet
    plume_pts = [(rider_cx - 2, head_y - 4), (rider_cx + 6, head_y - 14),
                 (rider_cx + 2, head_y - 2)]
    draw.polygon(plume_pts, fill=H("#C62828"))


def draw_healer_enemy(draw, frame):
    """
    HEALER ENEMY: tall robed support unit with glowing staff.
    Colors: white robe, emerald green hood, golden staff, soft green glow.
    Silhouette: tall, narrow, large distinct staff extends above head.
    """
    dy = WALK_BODY_DY[frame]
    cx = 40

    # --- Legs (under robe — barely visible) ---
    leg_y = 62 + dy
    lx = cx - 8 + WALK_LEG_LX[frame]
    rx = cx + 0 + WALK_LEG_RX[frame]
    outlined_rect(draw, lx, leg_y, 8, 16, H("#E8F5E9"))
    outlined_rect(draw, rx, leg_y, 8, 16, H("#E8F5E9"))

    # --- Robe body ---
    robe_pts = [
        (cx - 16, 34 + dy),   # left shoulder
        (cx + 16, 34 + dy),   # right shoulder
        (cx + 20, 78 + dy),   # right hem
        (cx - 20, 78 + dy),   # left hem
    ]
    outlined_polygon(draw, robe_pts, H("#F5F5F5"))
    # Green hood overlay / chest band
    draw.polygon([(cx - 14, 34 + dy), (cx + 14, 34 + dy),
                  (cx + 10, 50 + dy), (cx - 10, 50 + dy)], fill=H("#2E7D32"))
    # Robe trim lines
    for ry in [50, 58, 66]:
        draw.line([(cx - 18, ry + dy), (cx + 18, ry + dy)], fill=H("#C8E6C9"), width=1)

    # --- Staff (left arm, extends high above head) ---
    staff_x = cx - 20
    staff_top = 4 + dy
    staff_bot = 68 + dy
    draw.line([(staff_x - 1, staff_top + 14), (staff_x - 1, staff_bot)], fill=(0,0,0,255), width=5)
    draw.line([(staff_x, staff_top + 14), (staff_x, staff_bot)], fill=H("#F9A825"), width=3)
    # Staff orb (glowing green)
    for ri in range(14, 0, -2):
        alpha = int(80 + 160 * (14 - ri) / 14)
        draw.ellipse([staff_x - ri, staff_top - ri + 10,
                      staff_x + ri, staff_top + ri + 10],
                     fill=(100, 220, 100, alpha))
    # Staff orb outline
    draw.ellipse([staff_x - 8, staff_top + 2, staff_x + 8, staff_top + 18],
                 outline=H("#1B5E20"), width=2)

    # --- Arms ---
    # Left arm holding staff
    draw.line([(cx - 14, 46 + dy), (staff_x + 2, 48 + dy)], fill=H("#E8F5E9"), width=5)
    # Right arm (casting pose)
    draw.line([(cx + 14, 46 + dy), (cx + 24, 40 + dy)], fill=H("#E8F5E9"), width=5)
    # Casting glow at right hand
    for ri in range(8, 0, -1):
        alpha = int(40 * (8 - ri) / 8 + 20)
        draw.ellipse([cx + 18 + ri, 34 + dy + ri // 2,
                      cx + 30 + ri, 46 + dy - ri // 2],
                     fill=(100, 220, 100, alpha))

    # --- Head + green hood ---
    head_y = 14 + dy
    outlined_ellipse(draw, cx - 11, head_y + 2, 22, 22, H("#FFCC80"))  # face
    # Hood
    draw.ellipse([cx - 14, head_y - 6, cx + 14, head_y + 14], fill=H("#2E7D32"))
    draw.ellipse([cx - 14, head_y - 6, cx + 14, head_y + 14], outline=(0,0,0,255), width=2)
    # Face features
    draw.ellipse([cx - 6, head_y + 6, cx - 2, head_y + 10], fill=(0, 0, 0, 200))
    draw.ellipse([cx + 2, head_y + 6, cx + 6, head_y + 10], fill=(0, 0, 0, 200))
    # Small healing cross on hood
    hc_x, hc_y = cx + 2, head_y - 4
    draw.rectangle([hc_x - 1, hc_y - 4, hc_x + 1, hc_y + 4], fill=(255, 255, 255, 220))
    draw.rectangle([hc_x - 3, hc_y - 1, hc_x + 3, hc_y + 1], fill=(255, 255, 255, 220))


ENEMY_DRAWERS = {
    "infantry": draw_infantry,
    "archer":   draw_archer_enemy,
    "cavalier": draw_cavalier_enemy,
    "healer":   draw_healer_enemy,
}


def make_enemy_sprites():
    """Generate 4 walk frames for each of the 4 enemy types."""
    for name, drawer in ENEMY_DRAWERS.items():
        for frame in range(4):
            img = new_img(W, H_SPRITE)
            draw = ImageDraw.Draw(img)
            drawer(draw, frame)
            save(img, os.path.join(OUT, f"enemy_{name}_{frame}.png"))
    print(f"  Generated {len(ENEMY_DRAWERS) * 4} enemy frames.")


# ── Spell icons ───────────────────────────────────────────────────────────────

def make_spell_icons():
    """
    3 spell icons at 80x80 RGBA:
      spell_fire.png   — orange flame
      spell_lightning.png — yellow bolt
      spell_ice.png    — blue crystal burst
    """
    SIZE = 80
    cx = cy = 40
    R = 36

    # --- FIRE ---
    img = new_img(SIZE, SIZE)
    draw = ImageDraw.Draw(img)
    # Circle background
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], fill=H("#BF360C", 230))
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], outline=H("#FF5722"), width=3)
    # Flame body
    flame = [(cx, cy - 26), (cx + 12, cy - 8), (cx + 10, cy + 10),
             (cx + 2, cy + 20), (cx - 2, cy + 20), (cx - 10, cy + 10),
             (cx - 12, cy - 8)]
    draw.polygon(flame, fill=H("#FF6D00"))
    # Inner brighter flame
    inner = [(cx, cy - 18), (cx + 7, cy - 4), (cx + 5, cy + 8),
             (cx - 5, cy + 8), (cx - 7, cy - 4)]
    draw.polygon(inner, fill=H("#FFD600"))
    # Core white
    draw.ellipse([cx - 4, cy + 2, cx + 4, cy + 10], fill=H("#FFFFFF", 200))
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], outline=(0,0,0,200), width=2)
    save(img, os.path.join(OUT, "spell_fire.png"))

    # --- LIGHTNING ---
    img = new_img(SIZE, SIZE)
    draw = ImageDraw.Draw(img)
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], fill=H("#1A237E", 230))
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], outline=H("#3F51B5"), width=3)
    # Glow halo
    for ri in range(20, 0, -2):
        alpha = int(30 * (20 - ri) / 20)
        draw.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=(255, 235, 59, alpha))
    # Bolt shape (Z-zigzag)
    bolt = [(cx + 4, cy - 26), (cx - 4, cy - 4), (cx + 8, cy - 2),
            (cx - 6, cy + 26), (cx + 2, cy + 6), (cx - 10, cy + 4)]
    draw.polygon(bolt, fill=H("#FFD600"))
    # White core streak
    draw.line([(cx + 2, cy - 20), (cx - 2, cy - 2), (cx + 6, cy),
               (cx - 4, cy + 20)], fill=(255,255,255,200), width=2)
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], outline=(0,0,0,200), width=2)
    save(img, os.path.join(OUT, "spell_lightning.png"))

    # --- ICE ---
    img = new_img(SIZE, SIZE)
    draw = ImageDraw.Draw(img)
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], fill=H("#0D47A1", 230))
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], outline=H("#42A5F5"), width=3)
    # Snowflake — 6 arms
    arm_col = H("#E3F2FD")
    branch_col = H("#90CAF9")
    for angle in range(0, 360, 60):
        rad = math.radians(angle)
        ex = cx + int(22 * math.cos(rad))
        ey = cy + int(22 * math.sin(rad))
        draw.line([(cx, cy), (ex, ey)], fill=arm_col, width=3)
        # Branches on each arm
        for branch_frac in [0.4, 0.7]:
            bx = cx + int(22 * branch_frac * math.cos(rad))
            by = cy + int(22 * branch_frac * math.sin(rad))
            brad = math.radians(angle + 45)
            blen = 6
            draw.line([(bx, by), (bx + int(blen * math.cos(brad)),
                                   by + int(blen * math.sin(brad)))], fill=branch_col, width=2)
            brad2 = math.radians(angle - 45)
            draw.line([(bx, by), (bx + int(blen * math.cos(brad2)),
                                   by + int(blen * math.sin(brad2)))], fill=branch_col, width=2)
    # Center crystal
    draw.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=arm_col, outline=(0,0,0,180), width=2)
    draw.ellipse([cx - R, cy - R, cx + R, cy + R], outline=(0,0,0,200), width=2)
    save(img, os.path.join(OUT, "spell_ice.png"))


# ── Joystick base + knob ──────────────────────────────────────────────────────

def make_joystick():
    base = make_joystick_base()
    save(base, os.path.join(OUT, "joystick_base.png"))
    knob = make_joystick_knob()
    save(knob, os.path.join(OUT, "joystick_knob.png"))


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("Generating improved Garrison sprites...")
    print("\n-- Joystick --")
    make_joystick()
    print("\n-- Enemy sprites --")
    make_enemy_sprites()
    print("\n-- Spell icons --")
    make_spell_icons()
    print("\nDone.")


# ── Zone texture tiles ────────────────────────────────────────────────────────
# 11 deco styles × 128x128 RGBA tileable textures.
# Generated with a deterministic RNG so tiles are reproducible.

import random as _rand

def zone_tile(style: int) -> Image.Image:
    """Generate a 128×128 tileable texture for zone deco style [style]."""
    img = new_img(128, 128)
    px = img.load()
    rng = _rand.Random(style * 9973 + 42)

    # Style configs: (base_color_hex, detail_color_hex, detail_type, detail_count)
    configs = {
        0:  ("#1A4D1A", "#2E7D32", "dots",    60),   # Forest: dark green + lighter dots
        1:  ("#5D4E37", "#7A6648", "pebbles", 50),   # Cleared: sandy brown + pebbles
        2:  ("#4A4A4A", "#606060", "stones",  40),   # Ruins: grey stone blocks
        3:  ("#222232", "#3A3A4A", "rocks",   55),   # Catacombs: dark blue-grey rocks
        4:  ("#243325", "#2D4A2A", "puddles", 35),   # Swamp: muddy green puddles
        5:  ("#142036", "#1C3A5A", "sparkle", 80),  # Crystal forest: blue sparkles
        6:  ("#2A2520", "#1A1814", "ash",     70),  # Cendres: dark ash smears
        7:  ("#3A1205", "#5C2010", "embers",  60),  # Fire valley: ember patches
        8:  ("#B0C8D8", "#D8E8F0", "snow",   45),  # Tundra: snow patches
        9:  ("#3A3248", "#504060", "tiles",   30),  # Temple: stone tile grid
        10: ("#686888", "#808098", "peaks",   25),  # Mountain: peak marks
    }

    def fill_bg(hex_col):
        base = H(hex_col)
        for y in range(128):
            for x in range(128):
                # Slight noise variation per pixel
                noise = rng.randint(-8, 8)
                r = max(0, min(255, base[0] + noise))
                g = max(0, min(255, base[1] + noise))
                b = max(0, min(255, base[2] + noise))
                px[x, y] = (r, g, b, 255)

    cfg = configs.get(style)
    if cfg is None:
        return img

    if isinstance(cfg, tuple):
        base_hex, detail_hex, dtype, count = cfg
    else:
        # flat list format (style 2 and 3 defined as comma-separated above)
        base_hex, detail_hex, dtype, count = (
            "#4A4A4A", "#606060", "stones", 40) if style == 2 else (
            "#222232", "#3A3A4A", "rocks",  55)

    fill_bg(base_hex)
    draw = ImageDraw.Draw(img)
    dc = H(detail_hex)

    if dtype == "dots":
        for _ in range(count):
            x, y, r = rng.randint(2,125), rng.randint(2,125), rng.randint(2, 6)
            draw.ellipse([x-r, y-r, x+r, y+r], fill=(dc[0],dc[1],dc[2],180))
    elif dtype == "pebbles":
        for _ in range(count):
            x, y = rng.randint(3, 124), rng.randint(3, 124)
            w, h2 = rng.randint(4,10), rng.randint(3, 7)
            draw.ellipse([x, y, x+w, y+h2], fill=(dc[0],dc[1],dc[2],200))
    elif dtype == "stones":
        for _ in range(count):
            x, y = rng.randint(2,118), rng.randint(2,118)
            w, h2 = rng.randint(8,18), rng.randint(6,12)
            draw.rectangle([x, y, x+w, y+h2], fill=(dc[0],dc[1],dc[2],160))
            draw.line([x,y+h2, x+w,y+h2], fill=(0,0,0,80), width=1)
    elif dtype == "rocks":
        for _ in range(count):
            x, y = rng.randint(2,122), rng.randint(2,122)
            pts = [(x+rng.randint(0,8), y+rng.randint(0,6)) for _ in range(5)]
            draw.polygon(pts, fill=(dc[0],dc[1],dc[2],170))
    elif dtype == "puddles":
        for _ in range(count):
            x, y = rng.randint(4,120), rng.randint(4,120)
            w, h2 = rng.randint(10,22), rng.randint(5,12)
            draw.ellipse([x, y, x+w, y+h2], fill=(20, 50, 30, 120))
    elif dtype == "sparkle":
        for _ in range(count):
            x, y = rng.randint(1, 126), rng.randint(1, 126)
            draw.point([x, y], fill=(180, 220, 255, rng.randint(80, 220)))
            if rng.random() < 0.3:
                draw.line([x-2, y, x+2, y], fill=(200,230,255,100), width=1)
                draw.line([x, y-2, x, y+2], fill=(200,230,255,100), width=1)
    elif dtype == "ash":
        for _ in range(count):
            x, y = rng.randint(1,126), rng.randint(1,126)
            w, h2 = rng.randint(3,14), rng.randint(2,6)
            angle = rng.uniform(0, math.pi)
            draw.line([(x, y), (x+int(w*math.cos(angle)), y+int(h2*math.sin(angle)))],
                      fill=(dc[0],dc[1],dc[2],90), width=2)
    elif dtype == "embers":
        for _ in range(count):
            x, y = rng.randint(2,125), rng.randint(2,125)
            r = rng.randint(1, 4)
            alpha = rng.randint(100, 220)
            draw.ellipse([x-r, y-r, x+r, y+r], fill=(220, rng.randint(50,120), 10, alpha))
    elif dtype == "snow":
        for _ in range(count):
            x, y = rng.randint(3,124), rng.randint(3,124)
            w, h2 = rng.randint(8, 20), rng.randint(4, 10)
            draw.ellipse([x, y, x+w, y+h2], fill=(230, 240, 250, 180))
    elif dtype == "tiles":
        for tx in range(0, 128, 20):
            draw.line([tx, 0, tx, 127], fill=(dc[0],dc[1],dc[2],80), width=1)
        for ty in range(0, 128, 20):
            draw.line([0, ty, 127, ty], fill=(dc[0],dc[1],dc[2],80), width=1)
    elif dtype == "peaks":
        for _ in range(count):
            x, y = rng.randint(10, 118), rng.randint(20, 110)
            h2 = rng.randint(12, 24)
            pts = [(x, y), (x + rng.randint(8,18), y + h2 // 2),
                   (x - rng.randint(2,8), y + h2)]
            draw.polygon(pts, fill=(dc[0],dc[1],dc[2],100))

    return img


def make_zone_textures():
    """Generate 11 zone texture tiles (one per deco style)."""
    for style in range(11):
        img = zone_tile(style)
        path = os.path.join(OUT, f"zone_tex_{style}.png")
        save(img, path)
    print(f"  Generated 11 zone texture tiles.")


# ── Tower tier sprites ────────────────────────────────────────────────────────
# 4 visual tiers: Wood, Stone, Iron, Fortress (96×128 RGBA each).

def make_tower_tier_sprites():
    """Generate 4 tower tier sprites (96x128 RGBA)."""
    tiers = [
        # (suffix, body_hex, mortar_hex, batt_hex, accent_hex)
        ("tier_0", "#7C5228", "#9A6C3A", "#5C3A1A", "#B87840"),  # Wood
        ("tier_1", "#6E6E6E", "#8C8C8C", "#505050", "#B4B4B4"),  # Stone
        ("tier_2", "#3C3C5C", "#5A5A7A", "#2A2A44", "#8888B0"),  # Iron
        ("tier_3", "#3C3230", "#504540", "#28201E", "#C8A020"),  # Fortress
    ]

    for idx, (suffix, body_hex, mortar_hex, batt_hex, accent_hex) in enumerate(tiers):
        W, H2 = 96, 128
        img = new_img(W, H2)
        draw = ImageDraw.Draw(img)

        tower_h = 72 + idx * 10          # 72 / 82 / 92 / 102
        base_w  = 68
        base_x  = (W - base_w) // 2      # 14
        tower_y = H2 - 26 - tower_h       # bottom of tower body

        # --- Ground platform ---
        plat_w, plat_h = base_w + 8, 12
        plat_x = (W - plat_w) // 2
        plat_y = H2 - plat_h - 6
        outlined_rect(draw, plat_x, plat_y, plat_w, plat_h, H(body_hex))

        # --- Tower body ---
        outlined_rect(draw, base_x, tower_y, base_w, tower_h, H(body_hex))

        # --- Texture details ---
        if idx == 0:  # Wood: horizontal plank lines + knots
            y = tower_y + 10
            while y < plat_y - 2:
                draw.line([(base_x + 2, y), (base_x + base_w - 2, y)],
                          fill=H(mortar_hex), width=1)
                kx = base_x + base_w // 2 - 2
                draw.ellipse([kx, y - 3, kx + 4, y + 3], fill=H(mortar_hex, 140))
                y += 10

        elif idx == 1:  # Stone: brick grid
            bh = 13
            toggle = 0
            y = tower_y + 4
            while y < plat_y - 2:
                bw = 18
                x = base_x + 4 + (toggle * bw // 2)
                while x + bw < base_x + base_w - 4:
                    draw.rectangle([x, y, x + bw - 2, y + bh - 2],
                                   outline=H(mortar_hex, 130), width=1)
                    x += bw
                toggle = 1 - toggle
                y += bh

        elif idx == 2:  # Iron: reinforcement bands + rivets
            for frac in [0.28, 0.55, 0.80]:
                by = int(tower_y + tower_h * frac)
                draw.rectangle([base_x - 2, by - 3, base_x + base_w + 2, by + 3],
                               fill=H(accent_hex, 160), outline=H("#000000", 180), width=1)
            for frac in [0.28, 0.55, 0.80]:
                by = int(tower_y + tower_h * frac)
                draw.ellipse([base_x + 5, by - 2, base_x + 9, by + 2], fill=H(accent_hex))
                draw.ellipse([base_x + base_w - 9, by - 2, base_x + base_w - 5, by + 2],
                             fill=H(accent_hex))

        elif idx == 3:  # Fortress: large ashlar blocks + gold corner strips
            bh, bw = 16, 22
            y = tower_y + 4
            while y < plat_y - 2:
                x = base_x + 4
                while x + bw < base_x + base_w - 4:
                    draw.rectangle([x, y, x + bw - 2, y + bh - 2],
                                   outline=H(mortar_hex, 120), width=1)
                    x += bw
                y += bh
            # Gold corner columns
            draw.rectangle([base_x, tower_y, base_x + 4, plat_y],
                           fill=H(accent_hex, 100))
            draw.rectangle([base_x + base_w - 4, tower_y, base_x + base_w, plat_y],
                           fill=H(accent_hex, 100))

        # --- Arrow slits ---
        slits = 2 if idx < 3 else 3
        for si in range(slits):
            sx = base_x + base_w * (si + 1) // (slits + 1) - 2
            sy = tower_y + tower_h // 2 - 8
            draw.rectangle([sx, sy, sx + 4, sy + 14], fill=(0, 0, 0, 200))

        # --- Battlements ---
        bw2   = [12, 10, 10, 10][idx]
        bh2   = [10, 12, 12, 14][idx]
        bgap  = [ 8,  6,  6,  6][idx]
        nb    = 3 if idx < 3 else 4
        total = nb * bw2 + (nb - 1) * bgap
        bx0   = base_x + (base_w - total) // 2
        for bi in range(nb):
            bx = bx0 + bi * (bw2 + bgap)
            outlined_rect(draw, bx, tower_y - bh2, bw2, bh2 + 2, H(batt_hex))

        # --- Tier 2 extras: iron spikes above battlements ---
        if idx == 2:
            for sk in range(3):
                sx = base_x + base_w * (sk + 1) // 4
                pts = [(sx - 3, tower_y - bh2), (sx + 3, tower_y - bh2),
                       (sx, tower_y - bh2 - 9)]
                draw.polygon(pts, fill=H(accent_hex), outline=H("#000000", 140))

        # --- Tier 3 extras: flag/pennant ---
        if idx == 3:
            pole_x   = W // 2
            pole_top = tower_y - bh2 - 22
            draw.line([(pole_x, pole_top), (pole_x, tower_y - bh2)],
                      fill=H("#A0A0A0"), width=2)
            flag_pts = [(pole_x, pole_top),
                        (pole_x + 15, pole_top + 6),
                        (pole_x, pole_top + 12)]
            draw.polygon(flag_pts, fill=H(accent_hex))
            draw.polygon(flag_pts, outline=H("#000000", 150), width=1)

        path = os.path.join(OUT, f"tower_{suffix}.png")
        save(img, path)

    print("  Generated 4 tower tier sprites (tower_tier_0 … tower_tier_3).")


if __name__ == "__main__":
    print("\n-- Zone textures --")
    make_zone_textures()
    print("\n-- Tower tier sprites --")
    make_tower_tier_sprites()
