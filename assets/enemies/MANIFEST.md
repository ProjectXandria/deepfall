# DEEPFALL Phase 5 — enemy / melee / death-effect art manifest

Prepared 2026-11-05 from `~/workspace/asset-pipeline/staging/deepfall/` (read-only;
nothing in staging was modified). Rebuild: `build_phase5_assets.py` in the game root.

## Convention (all enemy frames)

- One common canvas per enemy, RGBA, transparent. Every frame pasted
  **bottom-centre**: content bottom = canvas bottom, so the game can anchor
  the sprite's feet at the collision-box bottom with a fixed offset.
- Each animation set is scaled independently so **that set's tallest frame is
  256px tall** (NEAREST resampling — pixel-art sources; LANCZOS was compared
  and softens the pixel read). Walk renders (~160–260px tall) and attack
  renders (~370–800px tall) come at very different source scales; a single
  scale per enemy would make walk frames ~80px tall next to a 256px attack.
  Per-set height normalisation keeps the creature the same on-screen size
  in walk, attack and idle.
- Frame counts below are EXACT — they match the files on disk. Game code
  should read counts from disk; if it hardcodes them, use these numbers.

## Enemies (`assets/enemies/<slug>/`)

| slug | canvas (WxH) | walk | walk source | attack | attack source | idle source |
|---|---|---|---|---|---|---|
| cave-bat-swarm | 399x256 | 4 | multiframe/mines-walk-v2 (bat 0–3) | 4 | multiframe/cave-bat-swarm-attack-v2 (0–3) | enemies/mines/full/cave-bat-swarm.png |
| miner-ghoul | 369x256 | 4 | multiframe/mines-walk-v2 (ghoul 0–3) | 4 | multiframe/miner-ghoul-attack-v2 (0–3) | enemies/mines/full/miner-ghoul.png |
| rock-golem | 344x256 | 4 | multiframe/mines-walk-v2 (golem 0–3) | 4 | multiframe/rock-golem-attack-v2 (0–3) | enemies/mines/full/rock-golem.png |
| cave-spider | 663x256 | 4 | multiframe/mines-walk-v2 (spider 0–3) | 4 | multiframe/cave-spider-attack-redo (0–3) | enemies/mines/full/cave-spider.png |
| ore-mimic | 462x256 | 4 | multiframe/mines-walk (mimic 0–3, top-cropped, see note) | **3** | multiframe/ore-mimic-attack-v2 (0–2) | enemies/mines/full/ore-mimic.png |
| tunnel-worm | 893x256 | **2** | multiframe/mines-walk (worm 0, 3 only, top-cropped, see note) | 4 | multiframe/tunnel-worm-attack-v2 (0–3) | enemies/mines/full/tunnel-worm.png |
| skeleton-warrior | 259x256 | 4 | KayKit bake (see note) | 4 | KayKit bake (see note) | KayKit bake (see note) |
| grave-revenant | 289x256 | 4 | multiframe/grave-revenant-walk-v2 (0–3) | 4 | multiframe/grave-revenant-attack-v2 (0–3) | enemies/ember-hollow/full/grave-revenant.png |
| ash-wraith | 373x256 | 4 | multiframe/ash-wraith-walk-v2 (0–3) | 4 | multiframe/ash-wraith-attack-redo (0–3) | enemies/ember-hollow/full/ash-wraith.png |
| skeleton-rogue | 191x256 | 4 | KayKit bake (see note) | 4 | KayKit bake (see note) | KayKit bake (see note) |

Scales applied (walk / attack / idle): bat 1.000 / 0.341 / 0.610;
ghoul 1.053 / 0.324 / 0.560; golem 0.992 / 0.433 / 0.554;
spider 1.524 / 0.688 / 0.721; mimic 1.778 / 0.425 / 0.632;
worm 2.048 / 0.453 / 0.886.
Chunk 1 (2026-11-14): revenant / wraith hi-res sets follow the same
convention (per-set tallest 256px, NEAREST, common canvas bottom-centre);
their game-size sets are LANCZOS downscales to 26px tall in
assets/enemies_px/ (KayKit-bake precedent), not NEAREST — see
build_chunk1_enemies.py.

Files per enemy: `walk_0.png … walk_N.png`, `attack_0.png … attack_N.png`,
`idle.png` (single-pose sprite, trimmed to content bbox, scaled to 256px tall).

## Notes / partial sets / contamination found

- **mines-walk-v2 verified on disk: only bat, ghoul, golem, spider** (4 frames
  each). Its raw composite's bottom mimic+worm band was deleted as mislabelled
  in history and was NOT re-sliced from the raw file.
- **v1 walk bleed (mimic, worm):** `mines-walk` frames carry bleed from the
  enemy row above in the source composite — spider legs dangling over the
  mimic row, mimic-chest rim over the worm row. The bleed is disconnected
  from the creature by a transparent gap (verified by connected-component
  analysis), so it was removed with a top crop before scaling: mimic walk
  cropped at y=67 (bleed ends ≤66, chest starts ≥69); worm walk cropped at
  y=53 (bleed ends ≤51, worm starts ≥58). Output frames are clean — verified
  visually on contact sheets.
- **tunnel-worm walk is 2 frames, not 4 (PARTIAL SET).** v1 worm frames 1–2
  show the worm longer than the frame: each is the head piece and the tail
  piece as two disconnected components with a ~100px transparent gap between
  them (the middle of the body is off-frame). Cycling them in place would
  read as the creature splitting apart. Only frames 0 and 3 — both clean
  full worms in different undulation poses — are shipped as `walk_0` /
  `walk_1`. Do not "fill in" frames 1–2 from the attack set; if a 4-frame
  walk is wanted, it needs a re-generation, not a re-slice.
- **ore-mimic attack is 3 frames (`attack_0..2`).** That is the complete
  `ore-mimic-attack-v2` set (open / chomp / closed). No 4th frame was
  invented.
- **cave-spider-attack-v2 NOT used** — it is partial (frames 1–2 only).
  `cave-spider-attack-redo` (4 frames) was used instead.

## KayKit skeleton-warrior bake (2026-11-13, CC0)

- Source: `~/workspace/asset-pipeline/staging/deepfall/kaykit-skeletons/`
  (`Skeleton_Warrior.glb` + `Skeleton_Blade.gltf`, blade parented to
  `handslot.r`). Baked in Blender 4.2.3 headless (Cycles CPU, 8 samples,
  orthographic side view from −Y, transparent film).
- Clips used (all real clips from the GLB, no invented frames):
  walk = `Walking_A_Rig` frames 0/7/13/20; attack =
  `1H_Melee_Attack_Chop_Rig` frames 2/9/16/23; idle = `Idle_Rig` frame 13.
- Hi-res sets in `assets/enemies/skeleton-warrior/`: per-set tallest =
  256px, NEAREST, bottom-centre — walk canvas 221x256, attack 259x256,
  idle 218x256.
- **The game loads `assets/enemies_px/`, not this folder.** The in-game
  frames in `assets/enemies_px/skeleton-warrior/` are the same renders
  NEAREST-downscaled per set to 26px tallest on one common 28x27 canvas,
  with the Phase 12 1px dark outline, plus `death_0..5.png` from the
  slump branch in `build_pixel_enemies.py` (same motion as miner-ghoul).
  Bake scripts: `/tmp/bake_warrior.py`, `/tmp/normalize_warrior.py`.
- STATS (`scripts/enemy.gd`): hp 25, speed 80, damage 8, aggro 280,
  range 56, half_w 12 (body, not the sword), half_h 32, walk 4, attack 4.
  Spawn: added to `ENEMY_SLUGS` in `scripts/main.gd` (uniform pick, 1/7).

## KayKit skeleton-rogue bake (2026-11-14, CC0, Chunk 1)

- Source: same KayKit pack (`Skeleton_Rogue.glb` +
  `Skeleton_Crossbow.gltf`, crossbow parented to `handslot.r` — visual
  only, the AI is melee). Baked in Blender 4.2.3 headless (Cycles CPU,
  32 samples, orthographic side view from −Y, transparent film).
  Bake script: `bake_rogue.py` in the project root; post-process:
  `bake_rogue_post.py`.
- Clips used (all real clips from the GLB, no invented frames):
  walk = `Walking_A_Rig` frames 0/7/13/20; attack =
  `1H_Melee_Attack_Stab_Rig` frames 2/13/24/35; idle = `Idle_Rig`
  frame 13. Gotcha: the GLB imports the rig with rotation_mode
  QUATERNION, so `rotation_euler` sets are no-ops — the bake script
  sets `rotation_mode = 'XYZ'` first, then rotates -90 deg about Z so
  the profile faces screen-left like the warrior.
- Hi-res sets in `assets/enemies/skeleton-rogue/`: per-set tallest =
  256px, NEAREST, bottom-centre — all sets on a common 191x256 canvas.
- **The game loads `assets/enemies_px/`, not this folder.** The in-game
  frames in `assets/enemies_px/skeleton-rogue/` are the same renders
  LANCZOS-downscaled to 26px tallest on one common 19x26 canvas, with
  the Phase 12 1px dark outline, plus `death_0..5.png` from the slump
  branch in `build_pixel_enemies.py`.
- STATS (`scripts/enemy.gd`): hp 15, speed 140, damage 6, aggro 320,
  range 52, half_w 12 (body, not the crossbow), half_h 32, walk 4,
  attack 4. Spawn: added to `ENEMY_SLUGS` in `scripts/main.gd`
  (uniform pick, 1/10).

- Source: `multiframe/tech-melee-v2/` (tech-soldier 0–3), 4 frames.
- The existing player convention (common 256x195 canvas at 0.5 scale) does
  **not** fit: melee frame 1 is 1031px wide (blade lunge) = 516px at 0.5.
  Instead the set is scaled 0.3076 so the tallest frame is 195px tall —
  the existing `player_anim` canvas height — and pasted bottom-centre on a
  common **317x195** canvas. Body then measures ~182px tall vs idle's
  ~190px, i.e. the soldier reads at the same size as idle/walk/shoot.
- Feet sit at the canvas bottom, so the Phase 5 wiring can anchor it like
  the other player anims: with Sprite2D scale 0.5, sprite y =
  40 − 195×0.5/2 = **−8.75**, the same offset `player.gd` already uses.

## Death effect (`assets/effects/death_0..3.png`)

- Source: `effects/smoke-puff.gif`, 4 frames, native 128x128, centred puff.
- Chosen over spore-puff (green), ember-burst (orange) and void-implosion
  (purple), which are element/themed; smoke is the generic poof for all six
  mines enemies.
- **Code fade required:** the frames grow but never dissipate — the last
  frame is the largest puff. Phase 5 code should fade the sprite's
  `modulate` alpha to 0 over the effect lifetime (or over the last ~0.15s).
  No fade frames were fabricated.
