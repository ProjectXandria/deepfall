"""build_chunk1_enemies.py - DEEPFALL Chunk 1: wire 3 staged enemies.

Converts the complete multiframe walk/attack sets from staging into the
two frame sets the game actually loads:

  assets/enemies/<slug>/{walk_N,attack_N,idle}.png   (256px hi-res set,
      Phase 5 convention: content-bbox trim, per-set tallest = 256px,
      NEAREST resampling, common canvas bottom-centre)
  assets/enemies_px/<slug>/{walk_N,attack_N,idle,death_N}.png
      (game-size set, KayKit-bake precedent: LANCZOS downscale of the
      256px frames so the set's tallest = 26px, common canvas
      bottom-centre; death frames from build_pixel_enemies.death_frames
      with the slump branch, same as skeleton-warrior)

Picks (complete 4+4 walk/attack sets in staging, dungeon-plausible
undead — the Mines is the only live region, so ember/fungal/void
creatures stay staged):
  grave-revenant, ash-wraith
NOT wired (gaps, see report): hollow-knight / hollow-archer (walk is
3 real frames + 1 frame TO DRAW by hand in Pencil2D — Skit's hand
step, see multiframe/*-walk-redo/NOTES.md); every void-deep slug
(walk only, no attack); crystal-warden / black-deep-eel / shadow-lurker
/ void-cultist / void-stalker / deep-tentacle-horror (walk only);
drowned-sailor (3-frame attack); spore-slime / mushroom-brute /
fungal-spitter-beast / coral-crab / sunken-diver-ghost / ember-imp /
lava-hound (complete sets but ember/fungal/sunken-themed, held for
their regions).

Run:  python3 build_chunk1_enemies.py
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
STAGING = "/home/hatch/workspace/asset-pipeline/staging/deepfall"
sys.path.insert(0, HERE)
import build_pixel_enemies as bpe  # noqa: E402  (death_frames, slump branch)

TARGET_H = 256
PX_H = 26

ENEMIES = {
    # slug: (walk dir, walk prefix, attack dir, attack prefix, idle path)
    "grave-revenant": (
        "multiframe/grave-revenant-walk-v2", "grave-revenant",
        "multiframe/grave-revenant-attack-v2", "grave-revenant",
        "enemies/ember-hollow/full/grave-revenant.png",
    ),
    "ash-wraith": (
        "multiframe/ash-wraith-walk-v2", "ash-wraith",
        "multiframe/ash-wraith-attack-redo", "ash-wraith",
        "enemies/ember-hollow/full/ash-wraith.png",
    ),
}


def load_frames(d, prefix, n=4):
    out = []
    for i in range(n):
        p = os.path.join(STAGING, d, "%s-%d.png" % (prefix, i))
        if not os.path.exists(p):
            raise SystemExit("MISSING FRAME: %s" % p)
        out.append(Image.open(p).convert("RGBA"))
    return out


def trim(im):
    bb = im.getbbox()
    return im.crop(bb) if bb else im


def process_set(frames, resample):
    """Trim, scale per-set tallest to TARGET_H, common canvas, bottom-centre."""
    trimmed = [trim(f) for f in frames]
    tallest = max(f.height for f in trimmed)
    scale = TARGET_H / tallest
    scaled = []
    for f in trimmed:
        nw = max(1, round(f.width * scale))
        nh = max(1, round(f.height * scale))
        scaled.append(f.resize((nw, nh), resample))
    w = max(f.width for f in scaled)
    out = []
    for f in scaled:
        c = Image.new("RGBA", (w, TARGET_H), (0, 0, 0, 0))
        c.alpha_composite(f, ((w - f.width) // 2, TARGET_H - f.height))
        out.append(c)
    return out, w


def downscale_px(frames256):
    """LANCZOS downscale of the 256px set so the tallest = PX_H."""
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
        out.append(c)
    return out, w


def main():
    for slug, (wd, wp, ad, ap, idle_rel) in ENEMIES.items():
        walk = load_frames(wd, wp)
        attack = load_frames(ad, ap)
        idle_src = Image.open(os.path.join(STAGING, idle_rel)).convert("RGBA")
        walk256, w = process_set(walk, Image.NEAREST)
        attack256, w2 = process_set(attack, Image.NEAREST)
        w = max(w, w2)
        # Idle: trimmed, 256 tall, same common width as the widest set.
        idle_t = trim(idle_src)
        iscale = TARGET_H / idle_t.height
        idle256 = idle_t.resize(
            (max(1, round(idle_t.width * iscale)), TARGET_H), Image.NEAREST)
        w = max(w, idle256.width)
        # Re-paste everything onto the final common canvas width.
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
        hi = os.path.join(HERE, "assets", "enemies", slug)
        os.makedirs(hi, exist_ok=True)
        for i, f in enumerate(walk256):
            f.save(os.path.join(hi, "walk_%d.png" % i))
        for i, f in enumerate(attack256):
            f.save(os.path.join(hi, "attack_%d.png" % i))
        idle_c.save(os.path.join(hi, "idle.png"))
        # Game-size px set.
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
        walk_px, attack_px = repaste_px(walk_px), repaste_px(attack_px)
        idle_px = repaste_px(idle_px)[0]
        px = os.path.join(HERE, "assets", "enemies_px", slug)
        os.makedirs(px, exist_ok=True)
        idle_px.save(os.path.join(px, "idle.png"))
        for i, f in enumerate(walk_px):
            f.save(os.path.join(px, "walk_%d.png" % i))
        for i, f in enumerate(attack_px):
            f.save(os.path.join(px, "attack_%d.png" % i))
        for i, f in enumerate(bpe.death_frames(slug, idle_px)):
            f.save(os.path.join(px, "death_%d.png" % i))
        print("%s: hi-res %dx%d walk/attack/idle, px %dx%d + 6 death" %
              (slug, w, TARGET_H, pw, PX_H))


if __name__ == "__main__":
    main()
