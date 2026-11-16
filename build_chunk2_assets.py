#!/usr/bin/env python3
"""Chunk 2 asset prep (DEEPFALL production chunk 2: terrain tiles).

PIL only, staged sources copied, never moved. Run from the project root.

1. Inner (concave) corner tiles, generated procedurally from the atlas
   fills (rock_0 / dirt_0, assets/atlas3/) in the Phase 9 style:
   - inner_rock_NE/NW/SE/SW, inner_dirt_NE/NW/SE/SW: full fill with a
     small jagged dark-cave bite taken out of the corner facing the air
     diagonal (the bite is SMALLER than the outer-corner cut: d < 20,
     vs 36 for outer corners — a concave notch, not a missing quarter).
   -> assets/tiles2/inner_*_v0.png (64x64, single variant each)
2. Third mining damage stage:
   - damage2.png: damage.png (stage 1) plus heavier crack polylines
     (deterministic seed 20261101) so stage 2 visibly supersedes stage 1.
   -> assets/damage2.png (64x64)
3. Staged slope / half-block / stair art (terraria-slopes/64/) copied
   into assets/tiles2/ as _v0/_v1 variants, plus horizontal flips for
   the left-facing direction (the staged art faces right only):
   - slope_{stone,dirt,brick,grass,obsidian}_{r,l}_v{0,1}.png
     (r2 staged file is the second variant)
   - half_{stone,dirt,wood}_v0.png (half-wood-platform -> half_wood)
   - stairs_{stone,wood}_{r,l}_v0.png (stairs face right; l is flipped)
   - ramp_{brick,wood}_v0.png copied for future decor use only — ramps
     are beams (VISUAL-SPEC section 4), never walkable terrain, and are
     NOT wired into the atlas by this script.
"""
import os
import random
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
STAGED = os.path.expanduser("~/workspace/asset-pipeline/staging/deepfall")
TILES2 = os.path.join(ROOT, "assets", "tiles2")
SLOPES = os.path.join(STAGED, "tiles-real", "terraria-slopes", "64")

rock = Image.open(os.path.join(ROOT, "assets", "atlas3", "rock_0.png")).convert("RGBA")
dirt = Image.open(os.path.join(ROOT, "assets", "atlas3", "dirt_0.png")).convert("RGBA")
assert rock.size == (64, 64) and dirt.size == (64, 64)


def jag(t: int) -> int:
    # Same deterministic jagged offset as build_phase9_assets.py.
    return ((t * 73 + 11) % 17) - 8


def inner_corner_tile(base: Image.Image, diag: str) -> Image.Image:
    # diag names the AIR diagonal (NE/NW/SE/SW). The notch is cut out of
    # that corner of the solid cell: d measures distance from the corner.
    out = base.copy()
    px_o = out.load()
    for y in range(64):
        for x in range(64):
            if diag == "NE":
                d = (63 - x) + y
            elif diag == "NW":
                d = x + y
            elif diag == "SE":
                d = (63 - x) + (63 - y)
            else:  # SW
                d = x + (63 - y)
            if d < 20 + jag((x + y) % 64):
                n = ((x * 31 + y * 17) % 9) - 4
                px_o[x, y] = (10 + n, 16 + n, 26 + n, 255)
    return out


os.makedirs(TILES2, exist_ok=True)
made = []
for diag in ["NE", "NW", "SE", "SW"]:
    inner_corner_tile(rock, diag).save(
        os.path.join(TILES2, "inner_rock_%s_v0.png" % diag))
    inner_corner_tile(dirt, diag).save(
        os.path.join(TILES2, "inner_dirt_%s_v0.png" % diag))
    made += ["inner_rock_%s" % diag, "inner_dirt_%s" % diag]
print("inner-corner tiles:", len(made), made)

# --- damage stage 2: stage 1 plus heavier cracks (deterministic) ---
dmg1 = Image.open(os.path.join(ROOT, "assets", "damage.png")).convert("RGBA")
dmg2 = dmg1.copy()
draw = ImageDraw.Draw(dmg2)
rng = random.Random(20261101)
CRACK = (20, 20, 26, 230)
# 12 new crack walks starting from random edge points, 1-2 px wide.
for _ in range(12):
    side = rng.randrange(4)
    if side == 0:
        x, y = rng.randrange(64), 0
    elif side == 1:
        x, y = rng.randrange(64), 63
    elif side == 2:
        x, y = 0, rng.randrange(64)
    else:
        x, y = 63, rng.randrange(64)
    pts = [(x, y)]
    steps = rng.randrange(10, 26)
    for _ in range(steps):
        x = max(0, min(63, x + rng.randrange(-6, 7)))
        y = max(0, min(63, y + rng.randrange(-6, 7)))
        pts.append((x, y))
    draw.line(pts, fill=CRACK, width=rng.choice([1, 1, 2]))
# A few chipped dark patches near the corners.
for _ in range(6):
    cx, cy = rng.randrange(64), rng.randrange(64)
    r = rng.randrange(2, 5)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(20, 20, 26, 200))
dmg2.save(os.path.join(ROOT, "assets", "damage2.png"))
n1 = sum(1 for p in dmg1.getdata() if p[3] > 10)
n2 = sum(1 for p in dmg2.getdata() if p[3] > 10)
print("damage stage1 opaque px=%d stage2 opaque px=%d" % (n1, n2))
assert n2 > n1 * 2, "stage 2 must be clearly heavier than stage 1"

# --- staged slope / half / stair art: copy + flip ---
made_slopes = []


def _load_staged(src_name: str) -> Image.Image:
    src = os.path.join(SLOPES, "%s.png" % src_name)
    assert os.path.exists(src), "missing staged slope art: %s" % src
    im = Image.open(src).convert("RGBA")
    assert im.size == (64, 64), (src, im.size)
    return im


for mat in ["stone", "dirt", "brick", "grass", "obsidian"]:
    # Two variants per material (r / r2) except brick, which has no r2
    # staged — each variant with a flipped left copy.
    staged_names = ["slope-%s-r" % mat, "slope-%s-r2" % mat]
    if mat == "brick":
        staged_names = staged_names[:1]
    for v, staged in enumerate(staged_names):
        im = _load_staged(staged)
        im.save(os.path.join(TILES2, "slope_%s_r_v%d.png" % (mat, v)))
        im.transpose(Image.FLIP_LEFT_RIGHT).save(
            os.path.join(TILES2, "slope_%s_l_v%d.png" % (mat, v)))
        made_slopes += ["slope_%s_r_v%d" % (mat, v),
                        "slope_%s_l_v%d" % (mat, v)]
for name, src in [("half_stone", "half-stone"),
                  ("half_dirt", "half-dirt"),
                  ("half_wood", "half-wood-platform")]:
    # Half-blocks are horizontally symmetric: one file, no flip copy.
    _load_staged(src).save(os.path.join(TILES2, "%s_v0.png" % name))
    made_slopes.append("%s_v0" % name)
for name, src in [("stairs_stone", "stairs-stone"),
                  ("stairs_wood", "stairs-wood")]:
    # stairs face right; the flipped copy is the left-facing variant.
    im = Image.open(os.path.join(SLOPES, "%s.png" % src)).convert("RGBA")
    im.save(os.path.join(TILES2, "%s_r_v0.png" % name))
    im.transpose(Image.FLIP_LEFT_RIGHT).save(
        os.path.join(TILES2, "%s_l_v0.png" % name))
    made_slopes += ["%s_r_v0" % name, "%s_l_v0" % name]
for name, src in [("ramp_brick", "ramp-brick"), ("ramp_wood", "ramp-wood")]:
    im = Image.open(os.path.join(SLOPES, "%s.png" % src)).convert("RGBA")
    im.save(os.path.join(TILES2, "%s_v0.png" % name))
    made_slopes.append("%s_v0 (decor only, not atlas-wired)" % name)
print("slope/half/stair files:", len(made_slopes))
for m in made_slopes:
    print("  ", m)
