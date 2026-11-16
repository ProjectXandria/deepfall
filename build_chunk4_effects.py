#!/usr/bin/env python3
"""Chunk 4: slice the 11 staged effect GIFs into PNG frames.

Source:  ~/workspace/asset-pipeline/staging/deepfall/effects/*.gif
         (128x128, 3-4 frames each, palette index 0 = transparent)
Output:  assets/effects/<name>_<i>.png  (same naive per-frame RGBA
         conversion as build_phase9_assets.py used for frost-burst ->
         orb_impact_0..2.png, which shipped in Phase 9).

Only slicing — no game code changes here. The frames are loaded by
main.gd _staged_frames() and spawned by _spawn_staged_burst().
"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
STAGED = os.path.expanduser("~/workspace/asset-pipeline/staging/deepfall/effects")
EFFECTS = os.path.join(HERE, "assets", "effects")

NAMES = [
    "acid-splash", "ember-burst", "explosion", "frost-burst",
    "heal-sparkle", "impact-sparks", "muzzle-flash", "slash-arc",
    "smoke-puff", "spore-puff", "void-implosion",
]

os.makedirs(EFFECTS, exist_ok=True)
total = 0
for name in NAMES:
    src = os.path.join(STAGED, name + ".gif")
    gif = Image.open(src)
    for i in range(gif.n_frames):
        gif.seek(i)
        gif.convert("RGBA").save(os.path.join(EFFECTS, "%s_%d.png" % (name, i)))
    print("%s: %d frames" % (name, gif.n_frames))
    total += gif.n_frames
print("total frames sliced: %d" % total)
