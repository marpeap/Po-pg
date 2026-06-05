#!/usr/bin/env python3
"""
Garrison — Complete sprite generation pipeline
Style: 3/4 top-down KingShot-inspired
Technique: 3x supersampling + LANCZOS downscale + outline pass
"""

from PIL import Image, ImageDraw, ImageFilter
import os, math

OUT = "/home/marpeap/Bureau/Game Developping/Claude-Code-Game-Studios/assets/sprites/garrison"
S = 3  # supersampling

# ─── PALETTE ───────────────────────────────────────────────────────────────
T     = (0,0,0,0)
OL    = (14, 9, 4, 248)      # outline dark

SK_L  = (238,200,160)        # skin light
SK_M  = (212,172,130)        # skin mid
SK_D  = (172,136, 96)        # skin dark
SK_X  = (145,108, 72)        # skin deep shadow

# Hero – blue plate armor
HA_HL = (148,178,228)        # armor highlight
HA_L  = (110,142,202)        # armor light face
HA_M  = ( 82,112,170)        # armor mid
HA_D  = ( 55, 80,138)        # armor shadow
HC_L  = (162,138,105)        # cloth/leather light
HC_M  = (132,110, 82)        # cloth mid
HC_D  = (100, 82, 58)        # cloth dark
H_HR  = ( 42, 27, 14)        # hero hair
H_BT  = ( 80, 62, 44)        # boots dark

# Archer – forest green
AG_HL = (118,172,112)
AG_L  = ( 98,150, 92)
AG_M  = ( 72,120, 68)
AG_D  = ( 48, 88, 45)
ABW   = (130, 95, 58)        # bow wood
ABW_L = (158,118, 75)
AQV   = ( 95, 70, 44)        # quiver

# Enemy – dark orc, red armor
EG_L  = ( 98,145, 88)        # orc skin light
EG_M  = ( 75,112, 65)
EG_D  = ( 52, 82, 45)
ER_HL = (215, 98, 82)
ER_L  = (200, 82, 68)
ER_M  = (162, 52, 44)
ER_D  = (122, 32, 26)
EHN   = (225,188, 58)        # horn gold
EHN_D = (168,138, 38)

# Ground
GR_L  = (112,165, 90)
GR_M  = ( 84,128, 62)
GR_D  = ( 58, 95, 40)
GR_X  = ( 42, 72, 28)
PT_L  = (192,168,125)
PT_M  = (162,140,102)
PT_D  = (128,108, 78)

# Castle – grey stone
CS_L  = (188,184,178)
CS_M  = (155,150,144)
CS_D  = (115,112,106)
CS_X  = ( 82, 78, 74)
CG_D  = ( 68, 50, 35)        # gate dark
CG_M  = ( 92, 70, 50)
CG_L  = (120, 95, 65)
C_FLG = (205, 52, 52)        # flag red
C_FGD = (255,220, 55)        # flag gold

# Barracks – warm sandstone
BR_L  = (202,182,150)
BR_M  = (170,152,120)
BR_D  = (135,118, 88)
BRR_L = (152,105, 70)        # roof light
BRR_M = (120, 80, 55)
BRR_D = ( 88, 58, 38)
BR_WD = (108, 82, 58)        # wooden beam

# Forge – dark iron
FG_L  = (138,130,125)
FG_M  = (105, 98, 92)
FG_D  = ( 72, 66, 62)
FF_O  = (248,158, 50)        # fire orange
FF_Y  = (255,222, 98)        # fire bright
FF_D  = (200, 92, 28)        # fire deep
FSM   = ( 42, 38, 34)        # smoke

# Tower – grey-blue stone
TW_L  = (182,180,192)
TW_M  = (150,148,160)
TW_D  = (112,110,120)
TW_B  = (130,128,138)        # battlements

# Horse – brown charger (cavalier hero)
HSB_H = (208,165,100)        # horse highlight
HSB_L = (180,135, 80)        # horse body light
HSB_M = (148,105, 58)        # horse body mid
HSB_D = (108, 76, 40)        # horse body dark
HSB_X = ( 72, 50, 26)        # horse shadow
HS_MN = ( 55, 35, 18)        # mane / tail dark
HS_HF = (230,215,195)        # horse blaze (nose)

# Trees
TR_L  = ( 98,165, 90)
TR_M  = ( 70,128, 64)
TR_D  = ( 44, 90, 38)
TK_L  = (115, 82, 54)        # trunk light
TK_M  = ( 88, 62, 42)
TK_D  = ( 62, 44, 28)

# Rock
RK_L  = (172,165,158)
RK_M  = (138,130,122)
RK_D  = ( 98, 92, 86)

# Gold / coin
GD_L  = (255,225, 92)
GD_M  = (222,182, 55)
GD_D  = (178,138, 36)

# ─── UTILITIES ─────────────────────────────────────────────────────────────

def new(w, h):
    return Image.new("RGBA", (w * S, h * S), T)

def px(v): return int(v * S)

def add_outline(img, thickness=2):
    _, _, _, a = img.split()
    mask = a.filter(ImageFilter.MaxFilter(thickness * 2 + 1))
    ol_data = [(OL if v > 18 else (0,0,0,0)) for v in mask.getdata()]
    ol = Image.new("RGBA", img.size)
    ol.putdata(ol_data)
    res = Image.new("RGBA", img.size, T)
    res.paste(ol)
    res.paste(img, mask=img)
    return res

def save_sprite(img, name, fw, fh, do_outline=True):
    if do_outline:
        img = add_outline(img)
    final = img.resize((fw, fh), Image.LANCZOS)
    final.save(os.path.join(OUT, name))
    print(f"  {name}  ({fw}x{fh})")

def tri(d, pts, fill):
    d.polygon(pts, fill=fill)

def rect(d, x1, y1, x2, y2, fill):
    d.rectangle([x1, y1, x2, y2], fill=fill)

def ell(d, cx, cy, rx, ry, fill):
    d.ellipse([cx-rx, cy-ry, cx+rx, cy+ry], fill=fill)

def trap(d, cx, yt, wt, yb, wb, fill):
    """Trapezoid: centered on cx, top width wt, bottom width wb."""
    d.polygon([
        (cx - wt//2, yt), (cx + wt//2, yt),
        (cx + wb//2, yb), (cx - wb//2, yb)
    ], fill=fill)

def box3d(d, cx, cy, bw, bh, bd, col_front, col_top, col_side):
    """Draw a simple 3D box in 3/4 perspective."""
    # Front face
    rect(d, cx - bw//2, cy, cx + bw//2, cy + bh, col_front)
    # Top face (rhombus/parallelogram)
    top_h = bd
    d.polygon([
        (cx - bw//2,   cy),
        (cx + bw//2,   cy),
        (cx + bw//2 + bd//2, cy - top_h),
        (cx - bw//2 + bd//2, cy - top_h),
    ], fill=col_top)
    # Right side face
    d.polygon([
        (cx + bw//2,           cy),
        (cx + bw//2 + bd//2,   cy - top_h),
        (cx + bw//2 + bd//2,   cy - top_h + bh),
        (cx + bw//2,           cy + bh),
    ], fill=col_side)

# ─── SHADOW ────────────────────────────────────────────────────────────────

def gen_shadow():
    print("shadow.png...")
    w, h = 72, 22
    img = Image.new("RGBA", (w, h), T)
    d = ImageDraw.Draw(img)
    cx, cy = w//2, h//2
    for r in range(min(w,h)//2, 0, -1):
        alpha = int(90 * (1 - r / (min(w,h)//2)))
        d.ellipse([cx - r*2, cy - r, cx + r*2, cy + r], fill=(15,10,5,alpha))
    img.save(os.path.join(OUT, "shadow.png"))
    print("  shadow.png  (72x22)")

# ─── CHARACTER DRAWING ─────────────────────────────────────────────────────

def draw_cavalier(frame):
    """Cavalier on horseback: 120x96 — blue plate armor knight on brown horse, 3/4 top-down."""
    W, H = 120*S, 96*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx = W // 2  # 180 at 3x

    # Walk bob and stride
    bob    = [0, -px(2), 0, -px(2)][frame]
    stride = px(5)  # horse leg stride

    # Horse body center (lower 55% of canvas)
    y_hbc  = H - px(36)    # horse body center y
    y_hbt  = y_hbc - px(18)  # horse body top
    y_hbb  = y_hbc + px(18)  # horse body bottom

    # Horse horizontal extent: left = head side, right = tail side
    hb_rx  = px(42)  # horse body x-radius
    hb_ry  = px(18)  # horse body y-radius
    hcx    = cx - px(4)  # horse body slightly left of canvas center

    # Leg x-positions (4 legs): front-pair left, back-pair right
    fl_x = hcx - px(22)  # front-left leg
    fr_x = hcx - px(10)  # front-right leg
    bl_x = hcx + px(8)   # back-left leg
    br_x = hcx + px(20)  # back-right leg
    leg_top = y_hbb - px(4)
    leg_bot = H - px(5)
    lw      = px(4)  # leg half-width

    # Leg y-offsets by animation frame (diagonal pairs)
    if frame == 1:
        fl_off, br_off = -stride, -stride
        fr_off, bl_off = +stride, +stride
    elif frame == 3:
        fl_off, br_off = +stride, +stride
        fr_off, bl_off = -stride, -stride
    else:
        fl_off = fr_off = bl_off = br_off = 0

    # ── BACK LEGS (behind body, draw first) ──
    # Back-right
    rect(d, br_x-lw, leg_top+br_off, br_x+lw, leg_bot+br_off, HSB_D)
    ell(d, br_x, leg_bot+br_off+px(2), lw+px(1), px(3), HSB_X)
    # Back-left
    rect(d, bl_x-lw, leg_top+bl_off, bl_x+lw, leg_bot+bl_off, HSB_D)
    ell(d, bl_x, leg_bot+bl_off+px(2), lw+px(1), px(3), HSB_X)

    # ── HORSE BODY ──
    ell(d, hcx, y_hbc, hb_rx, hb_ry, HSB_M)
    # Highlight stripe (top)
    ell(d, hcx-px(6), y_hbc-px(8), hb_rx-px(10), hb_ry-px(6), HSB_L)
    # Shadow rim (bottom)
    ell(d, hcx+px(4), y_hbb-px(5), hb_rx-px(8), px(7), HSB_D)
    # Tail (right side)
    ell(d, hcx+hb_rx-px(4), y_hbc+px(4), px(12), px(9), HS_MN)
    d.polygon([
        (hcx+hb_rx+px(6), y_hbc),
        (hcx+hb_rx+px(18), y_hbc+px(16)),
        (hcx+hb_rx+px(10), y_hbc+px(8)),
    ], fill=HS_MN)

    # ── HORSE NECK + HEAD ──
    neck_x = hcx - hb_rx + px(10)
    neck_top = y_hbt - px(8)
    trap(d, neck_x, y_hbt, px(16), neck_top, px(12), HSB_L)
    # Head
    hd_cx = neck_x - px(16)
    hd_cy = neck_top - px(4)
    ell(d, hd_cx, hd_cy, px(16), px(11), HSB_L)
    # Muzzle / blaze
    ell(d, hd_cx - px(12), hd_cy + px(2), px(8), px(6), HSB_M)
    ell(d, hd_cx - px(14), hd_cy + px(1), px(5), px(4), HS_HF)
    # Eye
    ell(d, hd_cx - px(8), hd_cy - px(4), px(3), px(3), (28,18,10))
    # Mane (dark strip from head to neck)
    rect(d, neck_x-px(2), neck_top, neck_x+px(5), y_hbt, HS_MN)

    # ── FRONT LEGS (in front of body) ──
    # Front-right
    rect(d, fr_x-lw, leg_top+fr_off, fr_x+lw, leg_bot+fr_off, HSB_M)
    ell(d, fr_x, leg_bot+fr_off+px(2), lw+px(1), px(3), HSB_D)
    # Front-left
    rect(d, fl_x-lw, leg_top+fl_off, fl_x+lw, leg_bot+fl_off, HSB_M)
    ell(d, fl_x, leg_bot+fl_off+px(2), lw+px(1), px(3), HSB_D)

    # ── RIDER UPPER BODY ──
    # Rider sits centered over front half of horse, bob with horse gait
    r_cx   = hcx - px(8)          # rider center x (slightly left)
    y_wst  = y_hbt - px(4) + bob  # waist just above horse top
    y_sh   = y_wst - px(24)       # shoulders
    y_nk   = y_wst - px(30)       # neck base
    y_hd_c = y_wst - px(40)       # helmet center

    # Torso
    trap(d, r_cx, y_sh, px(28), y_wst, px(22), HA_M)
    # Chest plate
    trap(d, r_cx, y_sh+px(2), px(18), y_wst-px(6), px(12), HA_L)
    rect(d, r_cx-px(3), y_sh+px(4), r_cx+px(3), y_wst-px(5), HA_HL)
    # Pauldrons
    ell(d, r_cx-px(14), y_sh+px(3), px(10), px(6), HA_L)
    ell(d, r_cx+px(14), y_sh+px(3), px(10), px(6), HA_L)
    # Belt
    rect(d, r_cx-px(14), y_wst-px(5), r_cx+px(14), y_wst, HC_D)

    # Arms (holding reins, angled toward horse neck)
    arm_L_off = [-px(3), +px(3), -px(3), +px(3)][frame]
    # Left arm
    rect(d, r_cx-px(16), y_sh+arm_L_off, r_cx-px(10), y_wst-px(4)+arm_L_off, HA_D)
    rect(d, r_cx-px(18), y_wst-px(8)+arm_L_off, r_cx-px(8), y_wst-px(4)+arm_L_off, HC_D)
    # Right arm (rein extended toward neck)
    rect(d, r_cx+px(10), y_sh, r_cx+px(16), y_wst-px(4), HA_M)
    rect(d, r_cx+px(8), y_wst-px(8), r_cx+px(18), y_wst-px(2), HC_M)
    # Reins
    d.line([(r_cx-px(12), y_wst-px(6)), (neck_x, y_hbt-px(4))], fill=HSB_X, width=max(1,px(1)))
    d.line([(r_cx+px(12), y_wst-px(6)), (neck_x+px(4), y_hbt-px(2))], fill=HSB_X, width=max(1,px(1)))

    # Helmet
    ell(d, r_cx, y_hd_c, px(14), px(13), HA_M)
    ell(d, r_cx, y_hd_c-px(4), px(10), px(9), HA_L)
    # Visor slit
    rect(d, r_cx-px(9), y_hd_c-px(1), r_cx+px(9), y_hd_c+px(3), HA_D)
    rect(d, r_cx-px(7), y_hd_c, r_cx+px(7), y_hd_c+px(2), (20,15,10))
    # Helmet plume (red)
    for pi in range(px(12)):
        alpha = max(0, 220 - pi * 16)
        d.point((r_cx + pi//3 - px(2), y_hd_c - px(13) - pi), fill=(210, 48, 48, alpha))
    # Neck (small strip below helmet)
    rect(d, r_cx-px(5), y_nk, r_cx+px(5), y_sh+px(3), SK_M)

    return img


## Keep backward-compatible alias — hero sprites are named hero_N.png
draw_hero = draw_cavalier


def draw_archer(frame):
    """Archer: 76x84 — forest green ranger with bow."""
    W, H = 76*S, 84*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx = W // 2

    bob    = [0, -px(2), 0, -px(2)][frame]
    stride = px(5)
    l_fwd  = (frame == 1)
    r_fwd  = (frame == 3)

    y_foot = H - px(3)
    y_kn   = H - px(26)
    y_hip  = H - px(37)
    y_wst  = H - px(44) + bob
    y_ch   = H - px(57) + bob
    y_sh   = H - px(63) + bob
    y_nk   = H - px(67) + bob
    y_hd_b = H - px(70) + bob
    y_hd_c = H - px(77) + bob
    y_hd_t = H - px(83) + bob

    lx_L = cx - px(10)
    lx_R = cx + px(10)
    lw = px(8)

    if l_fwd:
        l_top = y_hip + stride; l_bot = y_foot + stride
        r_top = y_hip - stride; r_bot = y_foot - stride
        arm_L_off = px(4); arm_R_off = -px(4)
    elif r_fwd:
        l_top = y_hip - stride; l_bot = y_foot - stride
        r_top = y_hip + stride; r_bot = y_foot + stride
        arm_L_off = -px(4); arm_R_off = px(4)
    else:
        l_top = y_hip; l_bot = y_foot
        r_top = y_hip; r_bot = y_foot
        arm_L_off = 0; arm_R_off = 0

    if l_top < r_top:
        back_lx, back_top, back_bot = lx_L, l_top, l_bot
        fwd_lx,  fwd_top,  fwd_bot  = lx_R, r_top, r_bot
    else:
        back_lx, back_top, back_bot = lx_R, r_top, r_bot
        fwd_lx,  fwd_top,  fwd_bot  = lx_L, l_top, l_bot

    arm_w = px(6)
    arm_top = y_sh
    arm_bot = y_wst + px(8)

    # Back leg
    back_kn = int((back_top + back_bot) * 0.45)
    trap(d, back_lx, back_top, lw*2, back_kn, lw*2, AG_D)
    trap(d, back_lx, back_kn, lw*2, back_bot, lw*2-px(2), AG_D)
    rect(d, back_lx-lw-px(1), back_bot-px(6), back_lx+lw+px(1), back_bot+px(2), HC_D)

    # Bow (left side, always visible)
    bow_x = cx - px(22)
    bow_top = y_sh - px(10)
    bow_bot = y_wst + px(18)
    bow_mid = (bow_top + bow_bot) // 2
    d.line([(bow_x-px(4), bow_top), (bow_x+px(4), bow_mid), (bow_x-px(4), bow_bot)],
           fill=ABW, width=px(2)+1)
    # Bowstring
    d.line([(bow_x-px(4), bow_top), (bow_x-px(4), bow_bot)],
           fill=(215,195,160,200), width=px(1))

    # Back arm (right)
    back_arm_cx = cx + px(17)
    back_arm_off = arm_R_off
    rect(d, back_arm_cx-arm_w+back_arm_off, arm_top,
             back_arm_cx+arm_w+back_arm_off, arm_bot, AG_D)

    # Torso
    trap(d, cx, y_sh, px(32), y_wst, px(27), AG_M)
    trap(d, cx, y_sh+px(2), px(18), y_ch, px(13), AG_L)
    # Hood/collar
    ell(d, cx, y_sh, px(18), px(8), AG_D)
    # Belt
    rect(d, cx-px(16), y_wst-px(3), cx+px(16), y_wst+px(4), HC_D)
    # Quiver on back
    rect(d, cx+px(14), y_sh, cx+px(20), y_ch+px(5), AQV)
    # Arrow sticking out of quiver
    d.line([(cx+px(17), y_sh-px(8)), (cx+px(17), y_sh)], fill=ABW, width=px(1)+1)

    # Front arm (left, holds bow string)
    front_arm_cx = cx - px(17)
    front_arm_off = arm_L_off
    rect(d, front_arm_cx-arm_w+front_arm_off, arm_top+front_arm_off//2,
             front_arm_cx+arm_w+front_arm_off, arm_bot+front_arm_off, AG_M)

    # Head
    hr_x = px(15); hr_y = px(18)
    rect(d, cx-px(6), y_hd_b, cx+px(6), y_sh+px(2), SK_M)  # neck
    ell(d, cx, y_hd_c, hr_x, hr_y, SK_M)
    ell(d, cx-px(3), y_hd_c-px(6), px(9), px(7), SK_L)  # forehead
    # Hood
    d.polygon([
        (cx-hr_x-px(4), y_hd_c+px(4)),
        (cx-hr_x,       y_hd_t+px(2)),
        (cx,            y_hd_t-px(8)),
        (cx+hr_x,       y_hd_t+px(2)),
        (cx+hr_x+px(4), y_hd_c+px(4)),
    ], fill=AG_D)
    # Hood front rim
    d.arc([cx-hr_x-px(3), y_hd_t+px(3), cx+hr_x+px(3), y_hd_c+px(6)],
          200, 340, fill=AG_M, width=px(2))
    # Eyes
    eye_y = y_hd_c - px(2)
    ell(d, cx-px(7), eye_y, px(4), px(3), (40,30,18))
    ell(d, cx+px(7), eye_y, px(4), px(3), (40,30,18))
    ell(d, cx-px(6), eye_y-px(1), px(2), px(2), (255,255,255,180))
    ell(d, cx+px(8), eye_y-px(1), px(2), px(2), (255,255,255,180))

    # Front leg
    fwd_kn_y = int((fwd_top + fwd_bot) * 0.45)
    trap(d, fwd_lx, fwd_top, lw*2, fwd_kn_y, lw*2, AG_M)
    trap(d, fwd_lx, fwd_kn_y, lw*2, fwd_bot, lw*2-px(2), AG_M)
    rect(d, fwd_lx-lw-px(2), fwd_bot-px(7), fwd_lx+lw+px(2), fwd_bot+px(3), HC_M)

    return img


def draw_enemy(frame):
    """Enemy: 80x88 — dark orc with red plate armor and horns."""
    W, H = 80*S, 88*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx = W // 2

    bob    = [0, -px(2), 0, -px(2)][frame]
    stride = px(6)
    l_fwd  = (frame == 1)
    r_fwd  = (frame == 3)

    y_foot = H - px(3)
    y_kn   = H - px(28)
    y_hip  = H - px(40)
    y_wst  = H - px(48) + bob
    y_ch   = H - px(62) + bob
    y_sh   = H - px(70) + bob
    y_hd_b = H - px(74) + bob
    y_hd_c = H - px(81) + bob
    y_hd_t = H - px(87) + bob

    lx_L = cx - px(13)
    lx_R = cx + px(13)
    lw = px(12)  # orcs are wider/bulkier

    if l_fwd:
        l_top = y_hip + stride; l_bot = y_foot + stride
        r_top = y_hip - stride; r_bot = y_foot - stride
        arm_L_off = px(5); arm_R_off = -px(5)
    elif r_fwd:
        l_top = y_hip - stride; l_bot = y_foot - stride
        r_top = y_hip + stride; r_bot = y_foot + stride
        arm_L_off = -px(5); arm_R_off = px(5)
    else:
        l_top = y_hip; l_bot = y_foot
        r_top = y_hip; r_bot = y_foot
        arm_L_off = 0; arm_R_off = 0

    if l_top < r_top:
        back_lx, back_top, back_bot = lx_L, l_top, l_bot
        fwd_lx,  fwd_top,  fwd_bot  = lx_R, r_top, r_bot
    else:
        back_lx, back_top, back_bot = lx_R, r_top, r_bot
        fwd_lx,  fwd_top,  fwd_bot  = lx_L, l_top, l_bot

    arm_w = px(9)  # orc arms thicker
    arm_top = y_sh
    arm_bot = y_wst + px(10)

    back_kn = int((back_top + back_bot) * 0.45)
    fwd_kn  = int((fwd_top  + fwd_bot)  * 0.45)

    # Back leg
    trap(d, back_lx, back_top, lw*2, back_kn, lw*2, ER_D)
    trap(d, back_lx, back_kn, lw*2, back_bot, lw*2-px(2), EG_D)
    rect(d, back_lx-lw, back_bot-px(8), back_lx+lw, back_bot+px(2), (52,40,28))

    # Back arm
    back_arm_cx = cx + px(22)
    back_arm_off = arm_R_off
    rect(d, back_arm_cx-arm_w+back_arm_off, arm_top,
             back_arm_cx+arm_w+back_arm_off, arm_bot, ER_D)
    # Hand/club
    ell(d, back_arm_cx+back_arm_off, arm_bot+px(6), arm_w+px(2), px(8), EG_D)

    # Torso (bulky)
    trap(d, cx, y_sh, px(44), y_wst, px(38), ER_M)
    trap(d, cx, y_sh+px(2), px(26), y_ch, px(20), ER_L)
    # Armor spikes/rivets
    for sx in [-px(16), 0, px(16)]:
        ell(d, cx+sx, y_sh+px(8), px(4), px(3), ER_D)
    # Belly
    ell(d, cx, y_wst-px(5), px(18), px(10), ER_D)
    # Belt
    rect(d, cx-px(22), y_wst-px(3), cx+px(22), y_wst+px(6), (52,40,28))

    # Front arm (orc left)
    front_arm_cx = cx - px(22)
    front_arm_off = arm_L_off
    rect(d, front_arm_cx-arm_w+front_arm_off, arm_top+front_arm_off//2,
             front_arm_cx+arm_w+front_arm_off, arm_bot+front_arm_off, ER_M)
    ell(d, front_arm_cx+front_arm_off, arm_bot+front_arm_off+px(6),
        arm_w+px(2), px(8), EG_M)

    # Head (orc — wider, with horns)
    hr_x = px(19); hr_y = px(19)
    rect(d, cx-px(8), y_hd_b, cx+px(8), y_sh+px(4), EG_M)  # thick neck
    ell(d, cx, y_hd_c, hr_x, hr_y, EG_M)
    ell(d, cx-px(5), y_hd_c-px(6), px(11), px(9), EG_L)  # lit side
    # Armor on head (battle helm partial)
    d.polygon([
        (cx-hr_x-px(2), y_hd_c+px(2)),
        (cx-hr_x,       y_hd_t+px(4)),
        (cx,            y_hd_t+px(1)),
        (cx+hr_x,       y_hd_t+px(4)),
        (cx+hr_x+px(2), y_hd_c+px(2)),
    ], fill=ER_D)
    # Horns
    horn_base_y = y_hd_t + px(6)
    # Left horn
    d.polygon([
        (cx-hr_x+px(2), horn_base_y),
        (cx-hr_x-px(4), horn_base_y),
        (cx-hr_x-px(8), y_hd_t-px(12)),
        (cx-hr_x-px(2), y_hd_t-px(8)),
    ], fill=EHN)
    d.polygon([
        (cx-hr_x-px(2), y_hd_t-px(8)),
        (cx-hr_x-px(8), y_hd_t-px(12)),
        (cx-hr_x-px(6), y_hd_t-px(14)),
    ], fill=EHN_D)
    # Right horn
    d.polygon([
        (cx+hr_x-px(2), horn_base_y),
        (cx+hr_x+px(4), horn_base_y),
        (cx+hr_x+px(8), y_hd_t-px(12)),
        (cx+hr_x+px(2), y_hd_t-px(8)),
    ], fill=EHN)
    d.polygon([
        (cx+hr_x+px(2), y_hd_t-px(8)),
        (cx+hr_x+px(8), y_hd_t-px(12)),
        (cx+hr_x+px(6), y_hd_t-px(14)),
    ], fill=EHN_D)
    # Eyes (glowing red-orange)
    eye_y = y_hd_c - px(2)
    ell(d, cx-px(8), eye_y, px(5), px(4), (220,80,40))
    ell(d, cx+px(8), eye_y, px(5), px(4), (220,80,40))
    ell(d, cx-px(7), eye_y-px(1), px(3), px(2), (255,180,80))
    ell(d, cx+px(9), eye_y-px(1), px(3), px(2), (255,180,80))
    # Tusks
    rect(d, cx-px(9), y_hd_c+px(10), cx-px(6), y_hd_c+px(18), (232,215,185))
    rect(d, cx+px(6), y_hd_c+px(10), cx+px(9), y_hd_c+px(18), (232,215,185))

    # Front leg
    trap(d, fwd_lx, fwd_top, lw*2+px(2), fwd_kn, lw*2+px(2), ER_M)
    trap(d, fwd_lx, fwd_kn, lw*2+px(2), fwd_bot, lw*2, EG_M)
    rect(d, fwd_lx-lw-px(1), fwd_bot-px(9), fwd_lx+lw+px(1), fwd_bot+px(3), (52,40,28))

    return img


# ─── BUILDINGS ─────────────────────────────────────────────────────────────

def gen_castle():
    """Castle: 200x220 — two towers, gatehouse, battlements."""
    W, H = 200*S, 220*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx = W // 2

    # === LEFT TOWER ===
    tx_L = px(38)
    tw_h = px(130); tw_w = px(52)
    tx1, tx2 = tx_L - tw_w//2, tx_L + tw_w//2
    ty_top = px(42)
    ty_bot = ty_top + tw_h

    # Left tower top face
    d.polygon([(tx1, ty_top), (tx2, ty_top),
               (tx2+px(18), ty_top-px(22)), (tx1+px(18), ty_top-px(22))], fill=CS_D)
    # Left tower right face (shadow)
    d.polygon([(tx2, ty_top), (tx2+px(18), ty_top-px(22)),
               (tx2+px(18), ty_bot-px(22)), (tx2, ty_bot)], fill=CS_X)
    # Left tower front face
    rect(d, tx1, ty_top, tx2, ty_bot, CS_M)
    # Stonework lines
    for ys in range(ty_top+px(15), ty_bot, px(20)):
        d.line([(tx1+px(2), ys), (tx2-px(2), ys)], fill=CS_D, width=px(1))
    for xs in range(tx1+px(8), tx2, px(16)):
        d.line([(xs, ty_top), (xs, ty_bot)], fill=CS_D, width=px(1))
    # Window
    win_cx = (tx1+tx2)//2; win_y = ty_top + px(45)
    ell(d, win_cx, win_y, px(7), px(10), CS_X)
    ell(d, win_cx, win_y, px(5), px(8), (40,50,80,200))  # dark window
    # Battlements (top of left tower)
    btl_y = ty_top - px(8)
    for bx in range(tx1+px(4), tx2-px(4), px(12)):
        rect(d, bx, btl_y-px(16), bx+px(8), btl_y, CS_L)

    # === RIGHT TOWER ===
    tx_R = px(162)
    tx3, tx4 = tx_R - tw_w//2, tx_R + tw_w//2
    ry_top = px(48)
    ry_bot = ry_top + tw_h - px(8)

    d.polygon([(tx3, ry_top), (tx4, ry_top),
               (tx4+px(18), ry_top-px(22)), (tx3+px(18), ry_top-px(22))], fill=CS_D)
    d.polygon([(tx4, ry_top), (tx4+px(18), ry_top-px(22)),
               (tx4+px(18), ry_bot-px(22)), (tx4, ry_bot)], fill=CS_X)
    rect(d, tx3, ry_top, tx4, ry_bot, CS_M)
    for ys in range(ry_top+px(15), ry_bot, px(20)):
        d.line([(tx3+px(2), ys), (tx4-px(2), ys)], fill=CS_D, width=px(1))
    win_cx2 = (tx3+tx4)//2; win_y2 = ry_top + px(40)
    ell(d, win_cx2, win_y2, px(7), px(10), CS_X)
    ell(d, win_cx2, win_y2, px(5), px(8), (40,50,80,200))
    for bx in range(tx3+px(4), tx4-px(4), px(12)):
        rect(d, bx, ry_top-px(8)-px(16), bx+px(8), ry_top-px(8), CS_L)

    # === CENTER GATEHOUSE ===
    gx1, gx2 = px(60), px(140)
    gy_top = px(72); gy_bot = px(210)
    # Top face
    d.polygon([(gx1, gy_top), (gx2, gy_top),
               (gx2+px(18), gy_top-px(22)), (gx1+px(18), gy_top-px(22))], fill=CS_D)
    # Front face
    rect(d, gx1, gy_top, gx2, gy_bot, CS_L)
    # Stonework
    for ys in range(gy_top+px(18), gy_bot, px(22)):
        d.line([(gx1+px(2), ys), (gx2-px(2), ys)], fill=CS_M, width=px(1))
    # Gate arch
    gate_cx = cx; gate_w = px(32); gate_top = gy_top + px(38)
    rect(d, gate_cx-gate_w, gate_top, gate_cx+gate_w, gy_bot, CG_M)
    # Gate arch cap
    ell(d, gate_cx, gate_top, gate_w, px(18), CG_M)
    ell(d, gate_cx, gate_top, gate_w-px(4), px(14), CG_D)
    # Portcullis lines
    for gx in range(gate_cx-gate_w+px(6), gate_cx+gate_w, px(10)):
        d.line([(gx, gate_top+px(2)), (gx, gy_bot)], fill=CG_D, width=px(1)+1)
    for gy in range(gate_top+px(12), gy_bot, px(14)):
        d.line([(gate_cx-gate_w+px(2), gy), (gate_cx+gate_w-px(2), gy)],
               fill=CG_D, width=px(1))
    # Battlements center
    for bx in range(gx1+px(4), gx2, px(12)):
        rect(d, bx, gy_top-px(22), bx+px(8), gy_top-px(6), CS_L)
    # Flag
    flag_x = cx - px(5); flag_y = gy_top - px(22)
    d.line([(flag_x, flag_y), (flag_x, flag_y-px(32))], fill=CS_D, width=px(2))
    d.polygon([
        (flag_x, flag_y-px(32)),
        (flag_x+px(28), flag_y-px(24)),
        (flag_x, flag_y-px(18)),
    ], fill=C_FLG)
    ell(d, flag_x+px(14), flag_y-px(25), px(7), px(5), C_FGD)

    return img


def gen_barracks():
    """Barracks: 150x140 — warm sandstone military building."""
    W, H = 150*S, 140*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx = W // 2

    bw = px(130); bh = px(75)
    bx1 = cx - bw//2; bx2 = cx + bw//2
    by_top = px(58); by_bot = by_top + bh

    # Roof (top face visible from above in 3/4)
    roof_h = px(30)
    # Ridge
    ridge_y = by_top - roof_h
    d.polygon([
        (bx1-px(4), by_top),
        (bx2+px(4), by_top),
        (cx+px(10), ridge_y),
        (cx-px(5),  ridge_y),
    ], fill=BRR_D)  # left slope (shadow)
    d.polygon([
        (bx2+px(4), by_top),
        (bx2+px(28), by_top-px(20)),
        (cx+px(30), ridge_y-px(20)),
        (cx+px(10), ridge_y),
    ], fill=BRR_M)  # right slope top
    d.polygon([
        (bx1-px(4), by_top),
        (cx-px(5),  ridge_y),
        (cx+px(15), ridge_y),
        (bx2+px(4), by_top),
    ], fill=BRR_M)

    # Right side top face
    d.polygon([(bx2, by_top), (bx2+px(28), by_top-px(20)),
               (bx2+px(28), by_bot-px(20)), (bx2, by_bot)], fill=BR_D)
    # Front face
    rect(d, bx1, by_top, bx2, by_bot, BR_M)
    # Lit center
    rect(d, bx1+px(8), by_top+px(4), bx2-px(8), by_bot-px(4), BR_L)
    # Wooden beams
    for beam_x in [bx1+px(26), bx1+px(52), bx1+px(78), bx1+px(104)]:
        rect(d, beam_x, by_top, beam_x+px(5), by_bot, BR_WD)
    # Door
    door_cx = cx; door_w = px(18); door_top = by_bot - px(36)
    rect(d, door_cx-door_w, door_top, door_cx+door_w, by_bot, CG_D)
    ell(d, door_cx, door_top, door_w, px(14), CG_D)
    # Door handle
    ell(d, door_cx+door_w-px(5), (door_top+by_bot)//2, px(3), px(3), GD_M)
    # Windows
    for wx in [bx1+px(18), bx2-px(18)]:
        win_y = by_top + px(18)
        rect(d, wx-px(10), win_y, wx+px(10), win_y+px(18), CS_X)
        d.line([(wx, win_y), (wx, win_y+px(18))], fill=CS_D, width=px(1)+1)
        d.line([(wx-px(10), win_y+px(9)), (wx+px(10), win_y+px(9))], fill=CS_D, width=px(1)+1)
    # Chimney
    ch_x = bx2 - px(25); ch_top = ridge_y - px(20); ch_bot = by_top - px(8)
    rect(d, ch_x-px(7), ch_top, ch_x+px(7), ch_bot, BR_D)
    rect(d, ch_x-px(9), ch_top-px(4), ch_x+px(9), ch_top, CS_D)

    return img


def gen_forge():
    """Forge: 170x155 — dark smithy with glowing furnace."""
    W, H = 170*S, 155*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx = W // 2

    bw = px(140); bh = px(78)
    bx1 = cx - bw//2; bx2 = cx + bw//2
    by_top = px(62); by_bot = by_top + bh

    # Flat roof (forge has a lower, more industrial look)
    top_h = px(22)
    # Top face
    d.polygon([(bx1-px(2), by_top), (bx2+px(2), by_top),
               (bx2+px(22), by_top-top_h), (bx1+px(22), by_top-top_h)],
              fill=FG_D)
    # Right side
    d.polygon([(bx2, by_top), (bx2+px(22), by_top-top_h),
               (bx2+px(22), by_bot-top_h), (bx2, by_bot)], fill=FG_D)
    # Front face
    rect(d, bx1, by_top, bx2, by_bot, FG_M)
    # Lit side
    rect(d, bx1+px(6), by_top+px(4), bx1+px(62), by_bot-px(4), FG_L)

    # Furnace opening (left side, glowing)
    furn_x = bx1 + px(20); furn_y = by_top + px(20)
    furn_w = px(28); furn_h = px(36)
    rect(d, furn_x, furn_y, furn_x+furn_w, furn_y+furn_h, (30,20,15))
    # Glow gradient
    for i, (gy, gw, col) in enumerate([
        (furn_y+furn_h-px(6), furn_w-px(4), FF_D),
        (furn_y+furn_h-px(12), furn_w-px(6), FF_O),
        (furn_y+furn_h-px(18), furn_w-px(10), FF_O),
        (furn_y+furn_h-px(22), furn_w-px(16), FF_Y),
    ]):
        d.polygon([
            (furn_x+furn_w//2-gw//2, gy),
            (furn_x+furn_w//2+gw//2, gy),
            (furn_x+furn_w//2+gw//2+px(2), gy+px(6)),
            (furn_x+furn_w//2-gw//2-px(2), gy+px(6)),
        ], fill=col)
    # Glow ambient on front wall
    for r in [px(28), px(22), px(16)]:
        alpha = max(0, 80 - r//px(1))
        ell(d, furn_x+furn_w//2, furn_y+furn_h//2, r, r,
            (255,150,40, min(80, alpha)))

    # Anvil (right side)
    anv_cx = bx1+px(100); anv_y = by_bot-px(18)
    rect(d, anv_cx-px(18), anv_y, anv_cx+px(18), anv_y+px(10), FG_D)
    rect(d, anv_cx-px(24), anv_y-px(6), anv_cx+px(24), anv_y+px(2), (80,78,74))
    rect(d, anv_cx-px(20), anv_y-px(10), anv_cx+px(20), anv_y-px(4), (95,92,88))

    # Chimney stack
    ch_x = bx2-px(30); ch_top = by_top-top_h-px(30); ch_bot = by_top-top_h+px(4)
    rect(d, ch_x-px(9), ch_top, ch_x+px(9), ch_bot, FSM)
    rect(d, ch_x-px(11), ch_top-px(4), ch_x+px(11), ch_top, FG_D)
    # Smoke wisps
    for si, (sx, sy_off, sa) in enumerate([(-px(3),0,90), (0,-px(8),70), (px(4),-px(16),50)]):
        ell(d, ch_x+sx, ch_top-px(10)-sy_off, px(6), px(8), (80,75,70, sa))

    # Door
    door_cx = cx+px(30); door_w = px(16); door_top = by_bot-px(40)
    rect(d, door_cx-door_w, door_top, door_cx+door_w, by_bot, CG_D)
    ell(d, door_cx, door_top, door_w, px(12), CG_D)

    # Metal reinforcement bands
    for bar_y in [by_top+px(20), by_top+px(50)]:
        rect(d, bx1, bar_y, bx2, bar_y+px(5), FG_D)

    return img


def gen_tower():
    """Archer Tower: 100x165 — tall stone tower with crenellations."""
    W, H = 100*S, 165*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx = W // 2

    tw = px(68); th = px(130)
    tx1 = cx - tw//2; tx2 = cx + tw//2
    ty_top = px(22); ty_bot = ty_top + th

    # Top face of tower
    top_h = px(18)
    d.polygon([(tx1, ty_top), (tx2, ty_top),
               (tx2+top_h, ty_top-top_h), (tx1+top_h, ty_top-top_h)],
              fill=TW_D)
    # Right side (shadow)
    d.polygon([(tx2, ty_top), (tx2+top_h, ty_top-top_h),
               (tx2+top_h, ty_bot-top_h), (tx2, ty_bot)], fill=TW_D)
    # Front face
    rect(d, tx1, ty_top, tx2, ty_bot, TW_M)
    # Lit column (left side)
    rect(d, tx1, ty_top, tx1+px(18), ty_bot, TW_L)

    # Stonework courses
    for sy in range(ty_top+px(18), ty_bot, px(22)):
        d.line([(tx1+px(2), sy), (tx2-px(2), sy)], fill=TW_D, width=px(1))
    for sx_range in [(tx1, tx1+px(18)), (tx1+px(18), tx2)]:
        for sx in range(sx_range[0]+px(6), sx_range[1], px(14)):
            d.line([(sx, ty_top), (sx, ty_bot)], fill=TW_D, width=px(1))

    # Arrow slits (windows)
    for wy in [ty_top+px(35), ty_top+px(75), ty_top+px(108)]:
        slit_w = px(5); slit_h = px(16)
        rect(d, cx-slit_w, wy, cx+slit_w, wy+slit_h, CS_X)
        ell(d, cx, wy, slit_w, px(5), CS_X)

    # Battlements (crenellations on top)
    btl_y = ty_top - px(6)
    for bx in range(tx1+px(4), tx2-px(4), px(13)):
        rect(d, bx, btl_y-px(18), bx+px(9), btl_y, TW_L)
    # Top walkway
    rect(d, tx1-px(4), ty_top-px(6), tx2+px(4), ty_top+px(2), TW_B)

    # Base (slightly wider)
    rect(d, tx1-px(5), ty_bot-px(12), tx2+px(5), ty_bot+px(4), TW_D)
    rect(d, tx1-px(8), ty_bot-px(6), tx2+px(8), ty_bot+px(8), TW_D)

    return img


# ─── TERRAIN ELEMENTS ──────────────────────────────────────────────────────

def gen_tree_large():
    """Large tree: 95x110 — 3/4 view with visible crown top."""
    W, H = 95*S, 110*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx = W // 2

    # Trunk
    tk_cx = cx - px(3)
    tk_top = H - px(38); tk_bot = H - px(8)
    tk_w = px(9)
    trap(d, tk_cx, tk_top, tk_w*2+px(4), tk_bot, tk_w*2+px(6), TK_M)
    # Trunk lit side
    rect(d, tk_cx-px(4), tk_top, tk_cx+px(2), tk_bot, TK_L)
    # Root flare
    d.polygon([
        (tk_cx-tk_w-px(10), tk_bot+px(4)),
        (tk_cx-tk_w, tk_bot),
        (tk_cx+tk_w, tk_bot),
        (tk_cx+tk_w+px(6), tk_bot+px(4)),
    ], fill=TK_D)

    # Crown — layered spheres for 3/4 depth
    crown_cx = cx; crown_cy = H - px(68)
    # Back/shadow crown
    ell(d, crown_cx+px(8),  crown_cy+px(15), px(28), px(22), TR_D)
    ell(d, crown_cx-px(10), crown_cy+px(18), px(25), px(20), TR_D)
    # Mid crown
    ell(d, crown_cx,        crown_cy+px(5),  px(38), px(30), TR_M)
    ell(d, crown_cx-px(18), crown_cy+px(10), px(28), px(22), TR_M)
    ell(d, crown_cx+px(18), crown_cy+px(8),  px(25), px(20), TR_M)
    # Top crown (lit from upper-left)
    ell(d, crown_cx-px(8),  crown_cy-px(10), px(32), px(28), TR_L)
    ell(d, crown_cx,        crown_cy,        px(38), px(28), TR_L)
    # Highlight top
    ell(d, crown_cx-px(12), crown_cy-px(14), px(18), px(14),
        (125, 195, 115, 200))

    return img


def gen_tree_small():
    """Small tree: 68x82."""
    W, H = 68*S, 82*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx = W // 2

    # Trunk
    tk_cx = cx
    tk_top = H - px(28); tk_bot = H - px(6)
    tk_w = px(7)
    trap(d, tk_cx, tk_top, tk_w*2, tk_bot, tk_w*2+px(4), TK_M)
    rect(d, tk_cx-px(3), tk_top, tk_cx+px(2), tk_bot, TK_L)

    crown_cx = cx; crown_cy = H - px(50)
    ell(d, crown_cx+px(6),  crown_cy+px(10), px(20), px(16), TR_D)
    ell(d, crown_cx-px(6),  crown_cy+px(12), px(18), px(14), TR_D)
    ell(d, crown_cx,        crown_cy+px(2),  px(28), px(22), TR_M)
    ell(d, crown_cx-px(12), crown_cy+px(6),  px(20), px(16), TR_M)
    ell(d, crown_cx+px(12), crown_cy+px(4),  px(18), px(14), TR_M)
    ell(d, crown_cx-px(6),  crown_cy-px(8),  px(24), px(20), TR_L)
    ell(d, crown_cx+px(4),  crown_cy-px(6),  px(22), px(18), TR_L)
    ell(d, crown_cx-px(8),  crown_cy-px(12), px(14), px(10),
        (122, 188, 112, 200))

    return img


def gen_rock():
    """Rock cluster: 85x58."""
    W, H = 85*S, 58*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)

    # Three rocks, largest in center
    def rock(rcx, rcy, rx, ry, lit=False):
        ell(d, rcx, rcy, rx, ry, RK_D)
        # Front/lit face
        ell(d, rcx-rx//3, rcy-ry//4, rx-px(3), ry-px(3), RK_M)
        if lit:
            ell(d, rcx-rx//2, rcy-ry//2, rx//2, ry//2, RK_L)
        # Cracks
        d.line([(rcx-px(3), rcy-ry+px(2)), (rcx+px(2), rcy+px(3))],
               fill=RK_D, width=px(1))

    rcx = W//2
    rcy = H//2

    rock(rcx-px(18), rcy+px(5), px(18), px(14), lit=True)
    rock(rcx+px(20), rcy+px(3), px(15), px(11))
    rock(rcx,        rcy-px(4), px(22), px(16), lit=True)

    return img


# ─── SMALL ASSETS ──────────────────────────────────────────────────────────

def gen_arrow():
    """Arrow projectile: 58x14."""
    W, H = 58*S, 14*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cy = H // 2

    # Shaft
    rect(d, px(8), cy-px(1), W-px(14), cy+px(1), (162,118,72))
    # Arrowhead
    d.polygon([(W-px(14), cy-px(4)), (W-px(2), cy), (W-px(14), cy+px(4))],
              fill=(165,158,150))
    d.polygon([(W-px(14), cy-px(3)), (W-px(5), cy), (W-px(14), cy+px(3))],
              fill=(210,205,200))
    # Fletching
    d.polygon([(px(2), cy-px(5)), (px(14), cy-px(2)), (px(14), cy+px(2)), (px(2), cy+px(5))],
              fill=(200,60,50))
    d.polygon([(px(2), cy), (px(14), cy-px(1)), (px(14), cy+px(1))],
              fill=(140,30,28))

    return img


def gen_coin():
    """Gold coin: 36x36."""
    W, H = 36*S, 36*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx, cy = W//2, H//2
    r = W//2 - px(3)

    ell(d, cx, cy, r, r, GD_D)
    ell(d, cx-px(2), cy-px(2), r-px(3), r-px(3), GD_M)
    ell(d, cx-px(4), cy-px(4), r-px(8), r-px(8), GD_L)
    # Shine
    ell(d, cx-r//2, cy-r//2, px(5), px(5), (255,248,210,220))
    # "G" mark
    d.arc([cx-px(6), cy-px(7), cx+px(6), cy+px(7)], 40, 310, fill=GD_D, width=px(2))
    rect(d, cx-px(1), cy-px(1), cx+px(6), cy+px(2), GD_D)

    return img


def gen_zone_ring(color_inner, alpha=45):
    """Zone marker ring: 220x220 — subtle ground disc."""
    W, H = 220*S, 220*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx, cy = W//2, H//2
    outer_r = W//2 - px(6)
    inner_r = outer_r - px(14)

    # Outer glow
    for r_off in range(px(8), 0, -1):
        a = int(alpha * (1 - r_off / px(8)) * 0.5)
        r, g, b = color_inner
        ell(d, cx, cy, outer_r+r_off, outer_r+r_off, (r,g,b,a))

    # Filled disc, semi-transparent
    r, g, b = color_inner
    ell(d, cx, cy, outer_r, outer_r, (r,g,b, alpha))
    # Inner lighter area
    ell(d, cx, cy, inner_r, inner_r, (r,g,b, alpha//2))
    # Ring border
    for w in [px(4), px(3), px(2), px(1)]:
        border_a = min(255, alpha * 3 + w*20)
        ell(d, cx, cy, outer_r-w, outer_r-w, (r,g,b, border_a))

    return img


def gen_icon(color, symbol):
    """Small icon: 48x48."""
    W, H = 48*S, 48*S
    img = Image.new("RGBA", (W, H), T)
    d = ImageDraw.Draw(img)
    cx, cy = W//2, H//2
    r = W//2 - px(4)

    r_c, g_c, b_c = color
    # Background circle
    ell(d, cx, cy, r, r, (r_c//3, g_c//3, b_c//3, 220))
    ell(d, cx-px(3), cy-px(3), r-px(4), r-px(4), color+(200,))
    ell(d, cx-px(6), cy-px(6), r-px(10), r-px(10), (min(255,r_c+40), min(255,g_c+40), min(255,b_c+40),180))

    # Symbol
    sw = px(10)  # stroke width
    if symbol == "sword":
        # Sword blade
        d.line([(cx, cy-r+px(6)), (cx, cy+r-px(6))], fill=(220,215,210), width=sw)
        # Crossguard
        d.line([(cx-px(14), cy+px(2)), (cx+px(14), cy+px(2))], fill=(190,170,100), width=sw-px(1))
        # Pommel
        ell(d, cx, cy+r-px(10), px(6), px(6), (190,170,100))
    elif symbol == "lightning":
        d.polygon([
            (cx+px(6), cy-r+px(8)),
            (cx-px(4), cy+px(2)),
            (cx+px(4), cy+px(2)),
            (cx-px(6), cy+r-px(8)),
            (cx+px(8), cy-px(4)),
            (cx-px(2), cy-px(4)),
        ], fill=(255,240,80))
    elif symbol == "magnet":
        # U-shape
        d.arc([cx-px(12), cy-px(14), cx+px(12), cy+px(8)], 180, 360,
              fill=(200,80,200), width=sw)
        rect(d, cx-px(12)-sw//2, cy-px(14), cx-px(12)+sw//2, cy+px(6), (200,80,200))
        rect(d, cx+px(12)-sw//2, cy-px(14), cx+px(12)+sw//2, cy+px(6), (200,80,200))
        ell(d, cx-px(12), cy+px(7), px(5), px(5), (255,50,50))
        ell(d, cx+px(12), cy+px(7), px(5), px(5), (80,80,255))
    elif symbol == "heart":
        d.polygon([
            (cx, cy+r-px(8)),
            (cx-px(16), cy-px(2)),
            (cx-px(16), cy-px(10)),
            (cx, cy-px(4)),
            (cx+px(16), cy-px(10)),
            (cx+px(16), cy-px(2)),
        ], fill=(230,60,80))
        ell(d, cx-px(9), cy-px(9), px(8), px(8), (230,60,80))
        ell(d, cx+px(9), cy-px(9), px(8), px(8), (230,60,80))
        ell(d, cx-px(5), cy-px(12), px(4), px(4), (255,120,140))

    return img


# ─── BACKGROUND ────────────────────────────────────────────────────────────

def gen_background():
    """World background: 1920x1080 landscape — castle left, field center, enemies right."""
    print("background.png (1920x1080)...")
    W, H = 1920, 1080
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)

    # Base: uniform grass field across full canvas
    for y in range(H):
        var = ((y * 7 + y // 30 * 13) % 9) - 4
        r = max(0, min(255, 84 + var))
        g = max(0, min(255, 130 + var))
        b = max(0, min(255, 60 + var))
        d.line([(0, y), (W, y)], fill=(r, g, b))

    # Castle zone (x=0..340): stone/cobblestone — stepped gradient via overlay rects
    castle_zone_w = 340
    steps = 12
    for step in range(steps):
        x0 = step * (castle_zone_w // steps)
        x1 = (step + 1) * (castle_zone_w // steps)
        t  = 1.0 - step / steps          # 1.0 at left edge, 0 at x=340
        r  = int(84 * (1-t) + 138 * t)
        g_c = int(130 * (1-t) + 125 * t)
        b_c = int(60 * (1-t) + 108 * t)
        d.rectangle([x0, 0, x1, H], fill=(r, g_c, b_c))

    # Cobblestone grid pattern in castle zone
    for row_y in range(0, H, 28):
        ox = 28 if (row_y // 28) % 2 == 0 else 0
        for col_x in range(0, castle_zone_w, 55):
            x1 = col_x + ox
            x2 = min(x1 + 52, castle_zone_w - 1)
            if x1 < x2:
                d.rectangle([x1, row_y, x2, row_y + 26], outline=(100, 98, 92, 160), width=1)

    # Castle-to-field transition strip (x=300..400)
    for x in range(300, 420):
        t = (x - 300) / 120
        for y in range(0, H, 2):  # every other line for speed
            r = int(138 * (1-t) + 84 * t)
            g_c = int(125 * (1-t) + 130 * t)
            b_c = int(108 * (1-t) + 60 * t)
            d.line([(x, y), (x, y+1)], fill=(r, g_c, b_c))

    # Main horizontal dirt path (y=460..620) — the battle lane
    path_y1, path_y2 = 460, 620
    for y in range(path_y1, path_y2):
        var = ((y * 11 + y // 20 * 7) % 7) - 3
        r = max(0, min(255, 160 + var))
        g_c = max(0, min(255, 138 + var))
        b_c = max(0, min(255, 100 + var))
        d.line([(castle_zone_w, y), (W, y)], fill=(r, g_c, b_c))
    # Path border lines
    d.line([(castle_zone_w, path_y1-3), (W, path_y1-3)], fill=(128, 108, 78), width=3)
    d.line([(castle_zone_w, path_y2+2), (W, path_y2+2)], fill=(128, 108, 78), width=3)

    # Secondary movement lanes (upper and lower thirds)
    for lane_y in [220, 860]:
        for y in range(lane_y, lane_y + 50):
            var = ((y * 5) % 5) - 2
            r = max(0, min(255, 92 + var))
            g_c = max(0, min(255, 140 + var))
            b_c = max(0, min(255, 68 + var))
            d.line([(castle_zone_w, y), (W, y)], fill=(r, g_c, b_c))

    # Enemy deployment zone (x=1680..1920): darkening overlay
    for x in range(1680, W):
        t = (x - 1680) / 240
        darkness = int(t * 38)
        for y in range(0, H, 3):  # every 3rd line for speed
            d.line([(x, y), (x, y+2)], fill=(
                max(0, 84 - darkness),
                max(0, 130 - darkness),
                max(0, 60 - darkness)
            ))

    # Grass texture details (tiny dots off path and castle zone)
    import random
    rng = random.Random(42)
    for _ in range(5000):
        gx = rng.randint(castle_zone_w + 10, W - 10)
        gy = rng.randint(0, H - 1)
        if not (path_y1 <= gy <= path_y2) and not (218 <= gy <= 272) and not (858 <= gy <= 912):
            col = rng.choice([(58, 95, 38), (72, 110, 50), (42, 82, 28)])
            d.ellipse([gx, gy, gx+3, gy+2], fill=col)

    img.save(os.path.join(OUT, "background.png"))
    print("  background.png  (1920x1080)")


# ─── MAIN ──────────────────────────────────────────────────────────────────

def main():
    print("\n=== Garrison Sprite Generation ===\n")
    print("Characters...")

    # Hero walk cycle — cavalier on horseback (landscape refactor)
    for fr in range(4):
        img = draw_cavalier(fr)
        save_sprite(img, f"hero_{fr}.png", 120, 96)

    # Archer walk cycle
    for fr in range(4):
        img = draw_archer(fr)
        save_sprite(img, f"archer_{fr}.png", 76, 84)

    # Enemy walk cycle
    for fr in range(4):
        img = draw_enemy(fr)
        save_sprite(img, f"enemy_{fr}.png", 80, 88)

    print("\nBuildings...")
    save_sprite(gen_castle(),   "castle.png",       200, 220)
    save_sprite(gen_barracks(), "barracks.png",     150, 140)
    save_sprite(gen_forge(),    "forge.png",        170, 155)
    save_sprite(gen_tower(),    "archer_tower.png", 100, 165)

    print("\nTerrain...")
    save_sprite(gen_tree_large(), "tree_lg.png", 95,  110)
    save_sprite(gen_tree_small(), "tree_sm.png", 68,  82)
    save_sprite(gen_rock(),       "rock.png",    85,  58)

    print("\nProjectiles & Collectibles...")
    save_sprite(gen_arrow(), "arrow.png", 58, 14)
    save_sprite(gen_coin(),  "coin.png",  36, 36)

    print("\nZone markers...")
    save_sprite(gen_zone_ring((120, 200, 120), 40), "zone_ring.png",      220, 220, do_outline=False)
    save_sprite(gen_zone_ring((120, 200, 120), 40), "zone_recruit.png",   220, 220, do_outline=False)
    save_sprite(gen_zone_ring((180, 120, 220), 40), "zone_targeting.png", 220, 220, do_outline=False)
    save_sprite(gen_zone_ring((220, 160, 80),  40), "zone_formation.png", 220, 220, do_outline=False)
    save_sprite(gen_zone_ring((220, 100, 80),  40), "zone_forge.png",     220, 220, do_outline=False)

    print("\nIcons...")
    save_sprite(gen_icon((160, 80,  80),  "sword"),     "icon_dmg.png", 48, 48, do_outline=False)
    save_sprite(gen_icon((80,  160, 220), "lightning"), "icon_spd.png", 48, 48, do_outline=False)
    save_sprite(gen_icon((180, 80,  200), "magnet"),    "icon_mag.png", 48, 48, do_outline=False)
    save_sprite(gen_icon((80,  180, 100), "heart"),     "icon_hp.png",  48, 48, do_outline=False)

    print("\nEffects...")
    gen_shadow()

    print("\nBackground...")
    gen_background()

    print("\n=== Done! ===")

if __name__ == "__main__":
    main()
