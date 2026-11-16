"""bake_rogue_post.py - DEEPFALL Chunk 1: post-process the Rogue bake.

Reads bake-out/skeleton-rogue/*.png (512px Blender renders) and writes
the two frame sets the game loads, same convention as the Warrior bake
and build_chunk1_enemies.py:
  assets/enemies/skeleton-rogue/{walk_N,attack_N,idle}.png
      (256px hi-res, NEAREST, per-set tallest 256, common canvas)
  assets/enemies_px/skeleton-rogue/{walk_N,attack_N,idle,death_N}.png
      (26px game set: LANCZOS downscale, Phase 12 1px dark outline,
      death frames from build_pixel_enemies.death_frames slump branch)

Run:  python3 bake_rogue_post.py
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_pixel_enemies as bpe  # noqa: E402

BAKE = os.path.join(HERE, "bake-out", "skeleton-rogue")
TARGET_H = 256
PX_H = 26


def trim(im):
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def process_set(frames):
    trimmed = [trim(f) for f in frames]
    tallest = max(f.height for f in trimmed)
    scale = TARGET_H / tallest
    scaled = []
    for f in trimmed:
        nw = max(1, round(f.width * scale))
        nh = max(1, round(f.height * scale))
        scaled.append(f.resize((nw, nh), Image.NEAREST))
    w = max(f.width for f in scaled)
    out = []
    for f in scaled:
        c = Image.new("RGBA", (w, TARGET_H), (0, 0, 0, 0))
        c.alpha_composite(f, ((w - f.width) // 2, TARGET_H - f.height))
        out.append(c)
    return out, w


def downscale_px(frames256):
    scale = PX_H / TARGET_H
    scaled = []
    for f in frames256:
        nw = max(1, round(f.width * scale))
        nh = max(1, round(f.height * scale))
        scaled.append(f.resize((nw, nh), Image.LANCZOS))
    w = max(f.width for f in scaled)
    out = []
    for f in scaled:
        c = Image.new("RGBA", (w, PX_H), (0, 0, 0, 0))
        c.alpha_composite(f, ((w - f.width) // 2, PX_H - f.height))
        out.append(bpe.outline(c))
    return out, w


def load(kind, n):
    out = []
    for i in range(n):
        p = os.path.join(BAKE, "%s_%d.png" % (kind, i))
        if not os.path.exists(p):
            raise SystemExit("MISSING BAKE FRAME: %s" % p)
        out.append(Image.open(p).convert("RGBA"))
    return out


def main():
    walk = load("walk", 4)
    attack = load("attack", 4)
    idle = load("idle", 1)[0]
    walk256, w = process_set(walk)
    attack256, w2 = process_set(attack)
    w = max(w, w2)
    idle_t = trim(idle)
    iscale = TARGET_H / idle_t.height
    idle256 = idle_t.resize(
        (max(1, round(idle_t.width * iscale)), TARGET_H), Image.NEAREST)
    w = max(w, idle256.width)

    def repaste(frames):
        out = []
        for f in frames:
            c = Image.new("RGBA", (w, TARGET_H), (0, 0, 0, 0))
            c.alpha_composite(f, ((w - f.width) // 2, 0))
            out.append(c)
        return out
    walk256, attack256 = repaste(walk256), repaste(attack256)
    idle_c = Image.new("RGBA", (w, TARGET_H), (0, 0, 0, 0))
    idle_c.alpha_composite(idle256, ((w - idle256.width) // 2, 0))

    hi = os.path.join(HERE, "assets", "enemies", "skeleton-rogue")
    os.makedirs(hi, exist_ok=True)
    for i, f in enumerate(walk256):
        f.save(os.path.join(hi, "walk_%d.png" % i))
    for i, f in enumerate(attack256):
        f.save(os.path.join(hi, "attack_%d.png" % i))
    idle_c.save(os.path.join(hi, "idle.png"))

    walk_px, pw = downscale_px(walk256)
    attack_px, pw2 = downscale_px(attack256)
    idle_px, pw3 = downscale_px([idle_c])
    pw = max(pw, pw2, pw3)

    def repaste_px(frames):
        out = []
        for f in frames:
            c = Image.new("RGBA", (pw, PX_H), (0, 0, 0, 0))
            c.alpha_composite(f, ((pw - f.width) // 2, 0))
            out.append(c)
        return out
    # NB: outline() ran inside downscale_px before repaste; the common
    # canvas paste keeps the outline intact (1px border inside the art).
    walk_px, attack_px = repaste_px(walk_px), repaste_px(attack_px)
    idle_px = repaste_px(idle_px)[0]
    px = os.path.join(HERE, "assets", "enemies_px", "skeleton-rogue")
    os.makedirs(px, exist_ok=True)
    idle_px.save(os.path.join(px, "idle.png"))
    for i, f in enumerate(walk_px):
        f.save(os.path.join(px, "walk_%d.png" % i))
    for i, f in enumerate(attack_px):
        f.save(os.path.join(px, "attack_%d.png" % i))
    for i, f in enumerate(bpe.death_frames("skeleton-rogue", idle_px)):
        f.save(os.path.join(px, "death_%d.png" % i))
    print("skeleton-rogue: hi-res %dx%d, px %dx%d + 6 death" % (w, TARGET_H, pw, PX_H))


if __name__ == "__main__":
    main()
