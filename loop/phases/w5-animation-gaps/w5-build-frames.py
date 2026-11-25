#!/usr/bin/env python3
"""W5: build the two missing enemy frames by PROC transforms only.

- ore-mimic attack_3.png: follow-through / recovery lunge.
  Source: attack_2.png (mouth closing, tongue out) translated +2 px
  toward the attack direction and +1 px down. Integer translation, so
  the palette is untouched and no pixel is resampled.
- tunnel-worm walk_2.png: mid-slither phase.
  Source: walk_1.png, lifted 1 px (headroom at the top), then a
  per-column vertical sine offset (amplitude 1 px, one wave across
  the 36 px body) — the travelling wave between walk_0 and walk_1.

Both frames are labelled PROC in staging ANIMATIONS.md. No new art
was drawn or generated; these are transforms of existing frames.
"""
import sys
from PIL import Image

BASE = "/home/hatch/workspace/goals/game-off-2026-entry/loop-scratch/w5-animation-gaps/assets/enemies_px"


def diff_frac(a: Image.Image, b: Image.Image) -> float:
    import numpy as np
    aa = np.array(a)
    bb = np.array(b)
    assert aa.shape == bb.shape
    return float((aa != bb).any(axis=2).mean())


def build_mimic() -> None:
    src = Image.open(f"{BASE}/ore-mimic/attack_2.png").convert("RGBA")
    w, h = src.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # +2 x (lunge forward), +1 y (settle down after the bite).
    out.paste(src, (2, 1), src)
    out.save(f"{BASE}/ore-mimic/attack_3.png")
    print("mimic attack_3: size", out.size,
          "diff vs attack_2: %.3f" % diff_frac(src, out),
          "diff vs attack_0: %.3f" % diff_frac(
              Image.open(f"{BASE}/ore-mimic/attack_0.png").convert("RGBA"), out))


def build_worm() -> None:
    import math
    src = Image.open(f"{BASE}/tunnel-worm/walk_1.png").convert("RGBA")
    w, h = src.size
    # Lift 1 px first: the body touches the bottom edge, so a sine
    # offset needs headroom at the bottom.
    lifted = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    lifted.paste(src, (0, -1), src)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # One full sine wave across the body, phase-shifted so the crest
    # sits between walk_0's and walk_1's wave positions.
    for x in range(w):
        dy = round(math.sin(2.0 * math.pi * x / 18.0 + math.pi * 0.75))
        col = lifted.crop((x, 0, x + 1, h))
        out.paste(col, (x, dy), col)
    out.save(f"{BASE}/tunnel-worm/walk_2.png")
    w0 = Image.open(f"{BASE}/tunnel-worm/walk_0.png").convert("RGBA")
    print("worm walk_2: size", out.size,
          "diff vs walk_0: %.3f" % diff_frac(w0, out),
          "diff vs walk_1: %.3f" % diff_frac(src, out))


if __name__ == "__main__":
    build_mimic()
    build_worm()
    print("W5 frames built")
