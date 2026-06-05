#!/usr/bin/env python3
"""
Find entity sprites (with transparency) in tower defense pack.
Terrain tiles are fully opaque (fill ~100%), entity sprites have transparency.
"""
from PIL import Image
import os, shutil

BASE = os.path.dirname(os.path.abspath(__file__))
KDIR = os.path.join(BASE, "kenney_downloads")
td_dir = os.path.join(KDIR, "tower-defense-top-down", "PNG", "Default size")
out_dir = os.path.join(BASE, "garrison")
sheet_dir = out_dir


def analyze_tile(path):
    img = Image.open(path).convert("RGBA")
    pixels = list(img.getdata())
    non_transparent = [(r, g, b, a) for r, g, b, a in pixels if a > 20]
    if not non_transparent:
        return 0.0, (0, 0, 0), img
    fill = len(non_transparent) / len(pixels)
    avg_r = sum(p[0] for p in non_transparent) // len(non_transparent)
    avg_g = sum(p[1] for p in non_transparent) // len(non_transparent)
    avg_b = sum(p[2] for p in non_transparent) // len(non_transparent)
    return fill, (avg_r, avg_g, avg_b), img


tiles = sorted(os.listdir(td_dir))
entity_tiles = []  # tiles with < 80% fill = have transparency = entity sprites

print("Entity sprites (transparent background):")
print(f"{'Tile':<32} {'Fill%':>6}  {'AvgRGB':>18}")

for f in tiles:
    path = os.path.join(td_dir, f)
    fill, rgb, img = analyze_tile(path)
    if 0.02 < fill < 0.80:
        num = int(''.join(c for c in f if c.isdigit()))
        entity_tiles.append((num, f, fill, rgb))
        print(f"  {f:<30} {fill*100:5.1f}%  rgb({rgb[0]:3d},{rgb[1]:3d},{rgb[2]:3d})")

print(f"\nTotal entity sprites: {len(entity_tiles)}")

# Build a contact sheet of just the entity sprites
from PIL import ImageDraw, ImageFont

COLS = 6
CELL = 80
LABEL_H = 20

rows = (len(entity_tiles) + COLS - 1) // COLS
w = COLS * CELL
h = rows * (CELL + LABEL_H) + 30
sheet = Image.new("RGBA", (w, h), (40, 40, 40, 255))
draw = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
except Exception:
    font = ImageFont.load_default()

draw.text((4, 4), "Tower Defense — Entity sprites (with transparency)", fill=(220, 220, 220), font=font)

for i, (num, fname, fill, rgb) in enumerate(entity_tiles):
    col = i % COLS
    row = i // COLS
    cx = col * CELL
    cy = row * (CELL + LABEL_H) + 30

    path = os.path.join(td_dir, fname)
    img = Image.open(path).convert("RGBA")
    img.thumbnail((CELL - 4, CELL - 4), Image.NEAREST)

    cell_bg = Image.new("RGBA", (CELL, CELL), (60, 60, 80, 255))
    for ty in range(0, CELL, 8):
        for tx in range(0, CELL, 8):
            if (tx // 8 + ty // 8) % 2 == 0:
                for py in range(ty, min(ty + 8, CELL)):
                    for px in range(tx, min(tx + 8, CELL)):
                        cell_bg.putpixel((px, py), (80, 80, 100, 255))
    ox = (CELL - img.width) // 2
    oy = (CELL - img.height) // 2
    cell_bg.paste(img, (ox, oy), img)
    sheet.paste(cell_bg, (cx, cy))
    draw.text((cx + 2, cy + CELL + 2), str(num), fill=(200, 200, 100), font=font)

out = os.path.join(sheet_dir, "_sheet_td_entities.png")
sheet.save(out)
print(f"\nSaved entity contact sheet: {out}")

# Copy the entity tiles as candidates
cand_dir = os.path.join(BASE, "garrison", "td_entities")
os.makedirs(cand_dir, exist_ok=True)
for num, fname, fill, rgb in entity_tiles:
    src = os.path.join(td_dir, fname)
    dst = os.path.join(cand_dir, fname)
    shutil.copy2(src, dst)
print(f"Copied {len(entity_tiles)} entity tiles to garrison/td_entities/")
