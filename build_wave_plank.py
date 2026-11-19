#!/usr/bin/env python3
"""Playtest fix wave Phase 3: redraw wood-platform as a thin one-way plank.

The v1.4 art was a full 64x64 block, brighter than solid wood (avg
145,101,80 vs wood 127,82,52) — it read as a solid wall, not a
pass-through platform. The new art is a plank in the top ~14 px of
the cell (the collision surface is the cell top) plus a small
downward chevron so it reads as one-way / drop-through, dimmed below
solid wood. Rows 23-63 stay transparent.

Run from anywhere:  python3 build_wave_plank.py
Applies in place to assets/tiles2/wood-platform_v0..3.png in the
worktree. The same plankify() is mirrored in build_assets.py so a
future asset rebuild reproduces it instead of reverting it.
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "deepfall-game", "assets", "tiles2")

HIGHLIGHT = (150, 108, 70)
BODY = (110, 74, 48)
SHADOW = (80, 52, 33)
SEAM = (70, 46, 28)
NAIL = (58, 38, 22)
CHEVRON = (95, 62, 38)
SEAM_X = [16, 32, 48, 24]


def plankify(vi: int) -> Image.Image:
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    px = im.load()
    for y in range(14):
        for x in range(64):
            if y < 2:
                c = HIGHLIGHT
            elif y < 11:
                c = BODY
            else:
                c = SHADOW
            px[x, y] = c + (255,)
    # vertical plank seam (variant-dependent position)
    sx = SEAM_X[vi % len(SEAM_X)]
    for y in range(2, 14):
        px[sx, y] = SEAM + (255,)
        px[sx + 1, y] = SEAM + (255,)
    # nails
    for nx in (8, 56) if vi != 3 else (8, 32, 56):
        for dx in (0, 1):
            for dy in (0, 1):
                px[nx + dx, 6 + dy] = NAIL + (255,)
    # downward chevron under the plank centre (one-way indicator)
    for y in range(14, 23):
        half = 22 - y
        for x in range(32 - half, 32 + half + 1):
            px[x, y] = CHEVRON + (255,)
    return im


def main() -> None:
    for vi in range(4):
        p = os.path.join(OUT, "wood-platform_v%d.png" % vi)
        plankify(vi).save(p)
        print("wrote", p)


if __name__ == "__main__":
    main()
