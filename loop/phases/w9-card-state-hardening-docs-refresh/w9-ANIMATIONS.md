# DEEPFALL animation index (2026-11-03, full pass)
Honest labels: SOURCE = frames taken from the original character sheets.
SYNTH = motion generated from a single static sprite (rotation, bob,
recoil, tint, fade, lunge). PROC = procedural effect drawn in code.
SYNTH/PROC previews show the motion; in Godot, replicate with
rotation/tween/particles on the sprite rather than treating the GIF
frames as hand-drawn animation.

## Player characters (animations/, 5 characters)
SOURCE, 6 each, from the regen-cleaned sheets: idle, walk, shoot,
reload, thruster, dying (30 GIFs + strips).
SYNTH, 2 each: hurt (red flicker), jump (vertical arc).
Total 40 GIFs. Missing for real: crouch, climb, melee attack, swim -
no source frames exist for these; they need new sheets, not transforms.

## Weapons (all)
- items-user melee (12): idle bob + swing attack (SYNTH)
- items-user ranged (14): idle bob + recoil attack (SYNTH)
  (iron-crossbow-BAD-MISLABELLED excluded; use sheet-28 crossbow)
- items-user ammo (12): idle bob + flight spin (SYNTH)
- items-user2 weapons (132: flasks, grenades, thrown, bombs,
  guns-special, shotguns, rifles, pistols, staves, polearms, blades,
  heavy): idle bob (new) + attack (swing/recoil/spin/pulse, existing)
- items-user3 tools (48: camp, exploration, crafting, mining):
  idle bob (new) + swing/pulse attack (existing)

## Enemies (enemies/animations/, 24)
SYNTH, 4 each: idle bob, attack lunge, hurt flicker, death fade.
Total 96 GIFs. Real walk/attack cycles need multi-frame sheets -
these are single poses, the lunge/hurt/death are transforms only.

## Effects (effects/, 11 PROC GIFs, shared)
muzzle-flash, explosion, impact-sparks, frost-burst, acid-splash,
spore-puff, ember-burst, void-implosion, smoke-puff, heal-sparkle,
slash-arc. Map by damage type: fire->ember-burst/explosion,
frost->frost-burst, acid->acid-splash, spore->spore-puff,
void->void-implosion, melee->slash-arc+impact-sparks,
guns->muzzle-flash, healing->heal-sparkle, bombs->explosion+smoke-puff.

## W5 (2026-11-13) — loop wave w5-animation-gaps, PROC only
- ore-mimic attack_3.png: PROC — follow-through lunge, attack_2.png
  translated +2x +1y (loop/phases/w5-animation-gaps/w5-build-frames.py).
  Attack set now 4/4; strike still lands inside the animation (clamped
  to 60% of the 0.5 s attack).
- tunnel-worm walk_2.png: PROC — mid-slither sine phase from walk_1.png
  (lifted 1 px, per-column sine offset amplitude 1 px, one wave across
  the body). Walk set now 3/3; cycle 0.5 s at 6 fps.
- red/mage fall/land: REUSE (verified) — the hero rig (hero_rig.gd) is
  procedural and class-agnostic; the fall flail and land squash come
  from the animation state, not per-class frames, so they apply
  identically to tech/red/mage. Verified in --selftest Phase 9
  (rig_fall_land lines for all three classes). No per-class fall/land
  frames exist or are needed; Skit's hand-drawn homework is untouched.

## Not animated (by design)
Armor, helmets, shields, boots, chest pieces: bob only (equipped
idle). They are equipment, not actors. Placeables, interactive
tiles, switches, destructibles: pulse/bob/shake previews already
in items-user3/animations/.

## Live game (2026-11-13) — what the staging previews became
- The live game now has **7 enemy kinds** with real pixel frames in
  `deepfall-game/assets/enemies_px/`: cave-bat-swarm, miner-ghoul,
  rock-golem, cave-spider, ore-mimic, tunnel-worm, skeleton-warrior.
  Each kind has walk / attack frames plus a 6-frame pixel death played
  by a falling corpse. The SYNTH lunge/hurt/death previews above were
  never shipped as game frames — the game uses these real frames.
- Skeleton-warrior: walk 4 / attack 4 / death 6 / idle 1, baked from
  the KayKit Skeletons GLB (CC0) in Blender headless — not from the
  Nov-3 sheets.
- The hero is the procedural paper-doll rig (`hero_rig.gd`), not the
  staging GIFs: run / idle / jump / fall / land / crouch / dash poses
  per class (tech / red / mage), fall flail and land squash from the
  animation state, verified in `--selftest` Phase 9 for all three
  classes.
- W6–W9 changed no animation. The only frame changes since W5 are
  none; the only new art since W5 is the KayKit skeleton-warrior set
  and chest prop (see MANIFEST.md "Status since 2026-11-03").
