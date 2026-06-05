#!/usr/bin/env python3
"""
Analyze tower defense tiles by visual content (non-transparent pixel density and color).
Helps identify which tiles are characters/entities vs terrain.
"""
from PIL import Image
import os

BASE = os.path.dirname(os.path.abspath(__file__))
KDIR = os.path.join(BASE, "kenney_downloads")
td_dir = os.path.join(KDIR, "tower-defense-top-down", "PNG", "Default size")
out_dir = os.path.join(BASE, "garrison")


def analyze_tile(path):
    img = Image.open(path).convert("RGBA")
    pixels = list(img.getdata())
    non_transparent = [(r, g, b, a) for r, g, b, a in pixels if a > 20]
    if not non_transparent:
        return 0, (0, 0, 0)
    fill = len(non_transparent) / len(pixels)
    avg_r = sum(p[0] for p in non_transparent) // len(non_transparent)
    avg_g = sum(p[1] for p in non_transparent) // len(non_transparent)
    avg_b = sum(p[2] for p in non_transparent) // len(non_transparent)
    return fill, (avg_r, avg_g, avg_b)


def is_gold_ish(rgb):
    r, g, b = rgb
    return r > 160 and g > 120 and b < 100  # warm yellow/gold

def is_brown_ish(rgb):
    r, g, b = rgb
    return r > 100 and g > 60 and b < 80 and r > g  # brown/wood

def is_gray_ish(rgb):
    r, g, b = rgb
    return abs(r - g) < 30 and abs(g - b) < 30 and r > 80  # gray/stone

def is_green_ish(rgb):
    r, g, b = rgb
    return g > r and g > b and g > 80  # green/grass/forest

tiles = sorted(os.listdir(td_dir))
print(f"{'Tile':<30} {'Fill%':>6}  {'Color':>15}  {'Category'}")
print("-" * 65)

gold_tiles = []
brown_tiles = []
gray_tiles = []

for f in tiles:
    path = os.path.join(td_dir, f)
    fill, rgb = analyze_tile(path)
    num = int(''.join(c for c in f if c.isdigit()))
    if fill < 0.05:
        continue  # Mostly empty

    cats = []
    if is_gold_ish(rgb):
        cats.append("GOLD/COIN")
        gold_tiles.append((num, f, fill, rgb))
    if is_brown_ish(rgb):
        cats.append("WOOD/TOWER")
        brown_tiles.append((num, f, fill, rgb))
    if is_gray_ish(rgb):
        cats.append("STONE/WALL")
        gray_tiles.append((num, f, fill, rgb))

    cat = "/".join(cats) if cats else ""
    if cat:
        print(f"  {f:<28} {fill*100:5.1f}%  rgb({rgb[0]:3d},{rgb[1]:3d},{rgb[2]:3d})  {cat}")

print(f"\nGold/coin candidates: {[t[0] for t in gold_tiles[:10]]}")
print(f"Wood/tower candidates: {[t[0] for t in brown_tiles[:10]]}")

# Copy best coin candidate
if gold_tiles:
    best_coin = gold_tiles[0]
    src = os.path.join(td_dir, best_coin[1])
    img = Image.open(src)
    img.save(os.path.join(out_dir, "coin.png"))
    print(f"\nCopied tile {best_coin[0]} as coin.png ({best_coin[1]})")
