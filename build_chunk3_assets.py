#!/usr/bin/env python3
"""Chunk 3 asset prep: tech swim + skeleton-hero anim sets.

Follows the Phase 8 recipe exactly (build_phase8_assets.py): strip sets
onto 128x195, big sets (walkcycle/melee/crouch/climb/swim) onto 256x195,
bottom-centre, never upscale. No AI images; PIL only.

Sources (reads ONLY from ~/workspace/asset-pipeline/staging/deepfall):
- multiframe/tech-swim-v2/tech-soldier-0..3.png: the tech swim set Phase 9
  left unwired (tech swim was 0). 4 frames, horizontal swim.
- cleaned-regen/skeleton-hero/: r0 idle 9, r1 walk 9, r2 shoot 5 + reload 4
  (r2c5..c8), r3 thruster 7, r4 dying 3 (r4c3..c5; r4c0..c2 are raw icons,
  skipped — same rule as tech/red). No fall frames exist for the skeleton
  (same as red/mage: airborne reuses thruster frame 0, land reuses the
  lowest crouch frame; both real frames of that character).
- multiframe/skeleton-{melee,crouch,climb,swim}-v2/skeleton-hero-0..3.png:
  4 frames each. No skeleton walk-cycle slice exists (skeleton-walk-v2
  holds only a reference.png), so the walkcycle samples the 9-frame walk
  strip at stride 2 (frames 0, 2, 4, 6) — the same 4 key poses.
- Climb frames have ladders baked in (same caveat as every other class);
  no climb/swim state exists in-game yet, so the sets are staged in the
  game tree but not driven — same as red/mage.

Writes ONLY under assets/player_anim/ in this project + MANIFEST.json.
Run from the project root.
"""
import json
import os
from PIL import Image

ROOT = os.path.dirname(os.path.abspath(__file__))
STAGED = os.path.expanduser("~/workspace/asset-pipeline/staging/deepfall")
OUT = os.path.join(ROOT, "assets", "player_anim")

CANVAS_SMALL = (128, 195)
CANVAS_BIG = (256, 195)


def paste_fit(frame: Image.Image, canvas_size: tuple) -> Image.Image:
    """Scale frame to fit the canvas (never upscale), paste bottom-centre."""
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    w, h = frame.size
    scale = min(canvas_size[0] / w, canvas_size[1] / h, 1.0)
    if scale < 1.0:
        frame = frame.resize((max(1, int(w * scale)), max(1, int(h * scale))),
                             Image.LANCZOS)
    canvas.paste(frame, ((canvas_size[0] - frame.width) // 2,
                         canvas_size[1] - frame.height), frame)
    return canvas


def save_set(files: list, dest_dir: str, set_name: str, canvas: tuple) -> int:
    os.makedirs(dest_dir, exist_ok=True)
    for i, src in enumerate(files):
        assert os.path.exists(src), "missing source frame: %s" % src
        im = Image.open(src).convert("RGBA")
        paste_fit(im, canvas).save(
            os.path.join(dest_dir, "%s_%d.png" % (set_name, i)))
    return len(files)


def staged(*parts: str) -> str:
    return os.path.join(STAGED, *parts)


manifest_path = os.path.join(OUT, "MANIFEST.json")
with open(manifest_path) as f:
    manifest = json.load(f)

# --- tech swim (flat root, like the other tech sets) ---
tech_swim = [staged("multiframe", "tech-swim-v2", "tech-soldier-%d.png" % i)
             for i in range(4)]
n = save_set(tech_swim, OUT, "swim", CANVAS_BIG)
manifest["classes"]["tech"]["swim"] = n
print("tech swim", n)

# --- skeleton hero (subfolder, like red/mage) ---
SKEL = staged("cleaned-regen", "skeleton-hero")
SKEL_OUT = os.path.join(OUT, "skeleton")
strip_sets = {
    "idle": ["r0c%d_idle.png" % i for i in range(9)],
    "walk": ["r1c%d_walk.png" % i for i in range(9)],
    "shoot": ["r2c%d_shoot.png" % i for i in range(5)],
    "reload": ["r2c%d_reload.png" % i for i in range(5, 9)],
    "thruster": ["r3c%d_thruster.png" % i for i in range(7)],
    # dying: r4c3..c5 only — r4c0..c2 are raw icons, skipped.
    "dying": ["r4c%d_dying.png" % i for i in range(3, 6)],
}
skel_counts = {}
for set_name, names in strip_sets.items():
    files = [os.path.join(SKEL, nm) for nm in names]
    n = save_set(files, SKEL_OUT, set_name, CANVAS_SMALL)
    skel_counts[set_name] = n
    print("skeleton", set_name, n)

# walkcycle: sample the 9-frame walk strip at stride 2 (no sliced set exists).
walkcycle = [os.path.join(SKEL, "r1c%d_walk.png" % i) for i in (0, 2, 4, 6)]
n = save_set(walkcycle, SKEL_OUT, "walkcycle", CANVAS_BIG)
skel_counts["walkcycle"] = n
print("skeleton walkcycle", n)

for set_name in ("melee", "crouch", "climb", "swim"):
    files = [staged("multiframe", "skeleton-%s-v2" % set_name,
                    "skeleton-hero-%d.png" % i) for i in range(4)]
    n = save_set(files, SKEL_OUT, set_name, CANVAS_BIG)
    skel_counts[set_name] = n
    print("skeleton", set_name, n)

skel_counts["fall"] = 0
manifest["classes"]["skeleton"] = skel_counts
manifest.setdefault("notes", []).append(
    "Chunk 3: tech swim wired (4, was 0) from multiframe/tech-swim-v2; "
    "skeleton hero added as an unlockable (never a starting class). "
    "Skeleton walkcycle samples the 9-frame walk strip at stride 2 "
    "(no sliced walk-cycle set exists; skeleton-walk-v2 is reference-only). "
    "No fall frames exist for the skeleton (same reuse rule as red/mage). "
    "Climb frames have ladders baked in; no climb/swim state in-game yet.")

with open(manifest_path, "w") as f:
    json.dump(manifest, f, indent=2)
print("Chunk 3 assets done:", json.dumps(manifest["classes"]["skeleton"]),
      "tech swim:", manifest["classes"]["tech"]["swim"])
