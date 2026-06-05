#!/usr/bin/env python3
"""
Create labeled contact sheets for all medieval RTS units, structures,
and tower defense tiles so we can identify sprites visually.
"""
from PIL import Image, ImageDraw, ImageFont
import os

BASE = os.path.dirname(os.path.abspath(__file__))
KDIR = os.path.join(BASE, "kenney_downloads")

COLS = 8
CELL = 80  # cell size
LABEL_H = 18


def make_sheet(sprites, title, out_path):
    rows = (len(sprites) + COLS - 1) // COLS
    w = COLS * CELL
    h = rows * (CELL + LABEL_H) + 30
    sheet = Image.new("RGBA", (w, h), (40, 40, 40, 255))
    draw = ImageDraw.Draw(sheet)

    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
    except Exception:
        font = ImageFont.load_default()

    draw.text((4, 4), title, fill=(220, 220, 220), font=font)

    for i, (name, path) in enumerate(sprites):
        col = i % COLS
        row = i // COLS
        cx = col * CELL
        cy = row * (CELL + LABEL_H) + 30

        img = Image.open(path).convert("RGBA")
        # Scale to fit cell with padding
        img.thumbnail((CELL - 4, CELL - 4), Image.NEAREST)
        # Center in cell (checkerboard background)
        cell_bg = Image.new("RGBA", (CELL, CELL), (60, 60, 80, 255))
        # Draw checkerboard
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

        # Label
        short = os.path.splitext(name)[0]
        # Extract just the number
        num = ''.join(c for c in short if c.isdigit())
        draw.text((cx + 2, cy + CELL + 2), num or short, fill=(200, 200, 100), font=font)

    sheet.save(out_path)
    print(f"Saved: {out_path}")


def main():
    out_dir = os.path.join(BASE, "garrison")
    os.makedirs(out_dir, exist_ok=True)

    # Medieval RTS units
    unit_dir = os.path.join(KDIR, "medieval-rts", "PNG", "Default size", "Unit")
    units = [(f, os.path.join(unit_dir, f)) for f in sorted(os.listdir(unit_dir)) if f.endswith(".png")]
    make_sheet(units, "Medieval RTS — Units (01..24)", os.path.join(out_dir, "_sheet_units.png"))

    # Medieval RTS structures
    struct_dir = os.path.join(KDIR, "medieval-rts", "PNG", "Default size", "Structure")
    structs = [(f, os.path.join(struct_dir, f)) for f in sorted(os.listdir(struct_dir)) if f.endswith(".png")]
    make_sheet(structs, "Medieval RTS — Structures (01..23)", os.path.join(out_dir, "_sheet_structures.png"))

    # Medieval RTS environment
    env_dir = os.path.join(KDIR, "medieval-rts", "PNG", "Default size", "Environment")
    envs = [(f, os.path.join(env_dir, f)) for f in sorted(os.listdir(env_dir)) if f.endswith(".png")]
    make_sheet(envs, "Medieval RTS — Environment (01..21)", os.path.join(out_dir, "_sheet_environment.png"))

    # Tower defense tiles (first 60)
    td_dir = os.path.join(KDIR, "tower-defense-top-down", "PNG", "Default size")
    td_tiles = [(f, os.path.join(td_dir, f)) for f in sorted(os.listdir(td_dir)) if f.endswith(".png")]
    make_sheet(td_tiles[:60], "Tower Defense — Tiles 001..060", os.path.join(out_dir, "_sheet_td_1.png"))
    make_sheet(td_tiles[60:150], "Tower Defense — Tiles 061..150", os.path.join(out_dir, "_sheet_td_2.png"))
    make_sheet(td_tiles[150:230], "Tower Defense — Tiles 151..230", os.path.join(out_dir, "_sheet_td_3.png"))
    make_sheet(td_tiles[230:], "Tower Defense — Tiles 231..299", os.path.join(out_dir, "_sheet_td_4.png"))

    print("\nOpen assets/sprites/garrison/_sheet_*.png to identify sprites.")


if __name__ == "__main__":
    main()
