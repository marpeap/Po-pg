#!/usr/bin/env python3
"""
Generate simple but clean sprites for entities that don't have good Kenney equivalents.
- coin.png: yellow coin icon
- arrow.png: arrow pointing right (rotated in-engine)
- joystick_base.png, joystick_knob.png: touch joystick visuals
- zone_recruit.png: recruit zone marker
- zone_forge.png: forge zone marker
- zone_targeting.png: targeting zone marker
- zone_formation.png: formation zone marker
- hp_bar_bg.png, hp_bar_fg.png: thin HP bar components
"""
from PIL import Image, ImageDraw
import os, math

BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(BASE, "garrison")
os.makedirs(OUT, exist_ok=True)


def save(img, name):
    path = os.path.join(OUT, name)
    img.save(path)
    print(f"  {name}: {img.size}")


def coin(size=64):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = size // 8
    # Outer gold circle
    d.ellipse([pad, pad, size - pad, size - pad], fill=(218, 165, 32, 255), outline=(180, 120, 0, 255), width=2)
    # Inner highlight
    hi = size // 4
    d.ellipse([hi, hi, size - hi, size - hi], fill=(255, 215, 0, 180))
    # 'G' letter or coin shine
    shine_x = size // 3
    shine_y = size // 4
    d.ellipse([shine_x, shine_y, shine_x + size // 6, shine_y + size // 8],
              fill=(255, 255, 200, 120))
    return img


def arrow(size=64):
    """Arrow pointing right — rotate in-engine to aim direction."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = size // 2, size // 2
    # Shaft
    d.line([(size // 6, cy), (size * 4 // 6, cy)], fill=(210, 160, 20, 255), width=5)
    # Arrowhead triangle
    tip_x = size - size // 6
    pts = [
        (tip_x, cy),
        (tip_x - size // 4, cy - size // 5),
        (tip_x - size // 4, cy + size // 5),
    ]
    d.polygon(pts, fill=(240, 200, 50, 255))
    return img


def joystick_base(size=160):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = 4
    d.ellipse([pad, pad, size - pad, size - pad],
              fill=(255, 255, 255, 50), outline=(255, 255, 255, 120), width=3)
    return img


def joystick_knob(size=80):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = 6
    d.ellipse([pad, pad, size - pad, size - pad],
              fill=(255, 255, 255, 180), outline=(255, 255, 255, 220), width=2)
    return img


def zone_circle(size=256, color=(100, 200, 100), alpha_fill=30, alpha_line=160, dashed=True):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = 8
    # Fill
    d.ellipse([pad, pad, size - pad, size - pad], fill=(*color, alpha_fill))
    if dashed:
        # Draw dashed circle manually
        num_segs = 32
        r = (size - pad * 2) // 2
        cx, cy = size // 2, size // 2
        for i in range(num_segs):
            if i % 2 == 0:
                a1 = (i / num_segs) * 2 * math.pi
                a2 = ((i + 1) / num_segs) * 2 * math.pi
                x1 = int(cx + r * math.cos(a1))
                y1 = int(cy + r * math.sin(a1))
                x2 = int(cx + r * math.cos(a2))
                y2 = int(cy + r * math.sin(a2))
                d.line([(x1, y1), (x2, y2)], fill=(*color, alpha_line), width=4)
    else:
        d.ellipse([pad, pad, size - pad, size - pad],
                  fill=(0, 0, 0, 0), outline=(*color, alpha_line), width=4)
    return img


def zone_rect(w=200, h=120, color=(100, 200, 100), alpha_fill=30, alpha_line=160):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = 6
    d.rectangle([pad, pad, w - pad, h - pad], fill=(*color, alpha_fill),
                outline=(*color, alpha_line), width=3)
    return img


if __name__ == "__main__":
    print("Generating sprites:")
    save(coin(64), "coin.png")
    save(arrow(48), "arrow.png")
    save(joystick_base(160), "joystick_base.png")
    save(joystick_knob(80), "joystick_knob.png")
    # Zone markers — dashed circles for recruit and forge zones
    save(zone_circle(256, (100, 220, 100), 25, 180), "zone_recruit.png")
    save(zone_circle(256, (220, 140, 50), 25, 180), "zone_forge.png")
    save(zone_circle(256, (160, 80, 220), 25, 180), "zone_targeting.png")
    save(zone_circle(256, (220, 180, 60), 25, 180), "zone_formation.png")
    print("Done.")
