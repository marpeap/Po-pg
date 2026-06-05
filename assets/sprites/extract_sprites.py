#!/usr/bin/env python3
"""
Extract and identify sprites from Kenney packs for Garrison.
Reads the medieval RTS XML spritesheet and extracts individual tiles.
"""

from PIL import Image
import os

BASE = os.path.dirname(os.path.abspath(__file__))
KDIR = os.path.join(BASE, "kenney_downloads")

# Kenney medieval RTS unit layout (from spritesheet visual reference):
# Units come in 6 color variants. Each variant has 4 unit types.
# Order within the sheet (approximate, verify from sizes):
# 01=blue knight, 02=blue archer, 03=blue banner, 04=blue worker
# 05=blue catapult, 06=blue commander, 07=red knight, 08=red archer...
# All units are ~18-20px wide, 24-26px tall (top-down RTS style)

# Garrison entity -> (pack, subdir, filename)
GARRISON_MAPPING = {
    "hero":         ("medieval-rts", "Unit",      "medievalUnit_01.png"),
    "archer":       ("medieval-rts", "Unit",      "medievalUnit_02.png"),
    "enemy_basic":  ("medieval-rts", "Unit",      "medievalUnit_07.png"),
    "enemy_fast":   ("medieval-rts", "Unit",      "medievalUnit_08.png"),
    "enemy_tank":   ("medieval-rts", "Unit",      "medievalUnit_13.png"),
    "castle":       ("medieval-rts", "Structure", "medievalStructure_01.png"),
    "archer_tower": ("medieval-rts", "Structure", "medievalStructure_07.png"),
    "forge":        ("medieval-rts", "Structure", "medievalStructure_10.png"),
    "barracks":     ("medieval-rts", "Structure", "medievalStructure_04.png"),
}

SCALE = 4  # Upscale factor (nearest-neighbor) — units are ~20x26px raw


def analyze():
    unit_dir = os.path.join(KDIR, "medieval-rts", "PNG", "Default size", "Unit")
    struct_dir = os.path.join(KDIR, "medieval-rts", "PNG", "Default size", "Structure")
    td_dir = os.path.join(KDIR, "tower-defense-top-down", "PNG", "Default size")

    print("=== Medieval RTS Units ===")
    for f in sorted(os.listdir(unit_dir)):
        img = Image.open(os.path.join(unit_dir, f))
        print(f"  {f}: {img.size}")

    print("\n=== Medieval RTS Structures ===")
    for f in sorted(os.listdir(struct_dir)):
        img = Image.open(os.path.join(struct_dir, f))
        print(f"  {f}: {img.size}")

    print("\n=== Tower Defense tiles (first 30) ===")
    tiles = sorted(os.listdir(td_dir))
    size_groups = {}
    for f in tiles:
        img = Image.open(os.path.join(td_dir, f))
        size_groups.setdefault(img.size, []).append(f)
    for size, files in sorted(size_groups.items(), key=lambda x: -len(x[1])):
        print(f"  {size}: {len(files)} tiles — {files[0]}..{files[-1]}")


def build_garrison_sprites():
    out_dir = os.path.join(BASE, "garrison")
    os.makedirs(out_dir, exist_ok=True)

    for name, (pack, subdir, filename) in GARRISON_MAPPING.items():
        src = os.path.join(KDIR, pack, "PNG", "Default size", subdir, filename)
        dst = os.path.join(out_dir, f"{name}.png")
        if not os.path.exists(src):
            print(f"  MISSING: {name} <- {src}")
            continue
        img = Image.open(src)
        scaled = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
        scaled.save(dst)
        print(f"  {name}.png  ({img.size} -> {scaled.size})")

    # Also copy coin tile from tower defense pack (tile around 100-140 range)
    # We'll grab several candidates and pick one
    td_dir = os.path.join(KDIR, "tower-defense-top-down", "PNG", "Default size")
    # Tower defense tiles 295-299 are usually projectiles/tokens
    for tile_num in [295, 296, 297, 298, 299]:
        src = os.path.join(td_dir, f"towerDefense_tile{tile_num:03d}.png")
        if os.path.exists(src):
            img = Image.open(src)
            scaled = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
            scaled.save(os.path.join(out_dir, f"td_tile{tile_num}.png"))
            print(f"  td_tile{tile_num}.png  ({img.size} -> {scaled.size})")

    print(f"\nOutput: {out_dir}")


if __name__ == "__main__":
    analyze()
    print("\n=== Building Garrison Sprites ===")
    build_garrison_sprites()
