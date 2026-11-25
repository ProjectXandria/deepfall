# DEEPFALL sprite pack — staging manifest

Source: user uploads 2026-11-03 ~16:08 PST, for the Godot 2D DEEPFALL game.
Status: STAGED ONLY. Not sliced, not wired into any Godot project, not published.
Originals remain in ~/workspace/user/files/; copies below are the working set.

All sheets: 1408x768 JPG, RGB, pixel-art animation sheets.
Each sheet has the same row layout, left to right:
- Row 1: Standing and Idle
- Row 2: Walking
- Row 3: Shooting, then Reloading, then Medication / Recharging (labels vary per sheet)
- Row 4: Thruster-pack
- Row 5: Icons (3, bottom left) and Dying (bottom right)

## Sheets

| File | Character | Notes |
|---|---|---|
| sheets/01-mud-creature.jpg | Mud / spore creature, green eyes, spits mud | Enemy candidate. Shooting row is mud-spit, not a gun. |
| sheets/02-gas-mask-soldier.jpg | Camo gas-mask soldier with rifle | |
| sheets/03-miner.jpg | Miner, headlamp, pickaxe / shovel, rifle | Strongest player candidate: mining tools + headlamp fit DEEPFALL's delver. |
| sheets/04-snake-soldier.jpg | Snake-bodied soldier, red visor, rifle | Enemy candidate. |
| sheets/05-dark-armor-soldier.jpg | Dark armored soldier, red visor, rifle | |
| sheets/06-gargoyle.jpg | Stone winged gargoyle | Enemy / boss candidate. |
| sheets/07-purple-witch.jpg | Purple-robed witch, staff, orb | Magic enemy / NPC candidate. |
| sheets/08-axe-knight.jpg | Bronze/teal armored knight, energy axe + rifle | Melee enemy / boss candidate. |
| sheets/09-tech-soldier.jpg | Blue tech-armor female soldier, rifle | |
| sheets/10-red-soldier.jpg | Red/black armored soldier | |
| sheets/11-red-soldier-duplicate.jpg | DUPLICATE of 10 — md5 b977a8e2dc00084f469e2c84faeb80ae, identical file | Do not ship twice. Kept only to record the duplicate upload. |
| sheets/12-hooded-mage.jpg | Hooded mage, purple orb / staff | Magic enemy / NPC candidate. |

Unique sheets: 12 (16 files, 4 duplicates: 11 = 10, 13 = 09, 14 = 12, 15 = 10).

## Additions 2026-11-03 ~16:12–16:15 PST

- sheets/13-tech-soldier-duplicate.jpg — duplicate of 09.
- sheets/14-hooded-mage-duplicate.jpg — duplicate of 12.
- sheets/15-red-soldier-duplicate.jpg — duplicate of 10.
- STARTING CLASSES (user's words 16:12 PST): the three re-sent sheets — tech soldier, hooded mage, red soldier — are the starting classes to choose from.
- sheets/16-skeleton-hero.jpg — NEW, distinct (1408x768, md5 178e3ae4...): hooded skeleton hero in purple robes with a floating skull companion. User's words 16:15 PST: "Here's another hero". Unconfirmed whether this is a 4th starting class or a separate hero.
- Miner identity (user's words 16:12 PST): the miner (03) is a mole miner.
- Cleaning order (user's words 16:12 PST): "Clean the cells" — in progress: slice + remove backdrop/labels to transparent PNGs, starting with the starting classes + miner, skeleton hero queued next. The skeleton hero sheet's background is a baked-in grey checkerboard (JPG, no real transparency) — cleaning must remove that checker, not just the dark room backdrop.

## Slicing limits — read before wiring

- These are presentation sheets, not clean Godot sprite sheets: each cell has a dark room backdrop, a floor line, grid dividers, and text labels ("Standing and Idle", "Walking", etc.) overlapping some cells.
- Background is NOT transparent, and it is not a single flat colour to key out cleanly.
- Grid slicing into AtlasTexture regions is possible, but the labels and backdrop will come with the frames unless the cells are cleaned or clean source frames are supplied.
- Do NOT claim these are sliced / transparent / Godot-ready until that cleaning step is done and QC'd.

## Open decisions (user's picks)

1. Which character is the player? Proposed: 03-miner. Unconfirmed.
2. Which sheets are enemies, NPCs, or unused?
3. Slicing approach: (a) slice these sheets as-is with backdrop included, (b) clean cells to transparency, or (c) supply clean source frames without labels/backdrop.
4. No tiles, items, or environment art in this batch — characters only.

## Next step when confirmed

Slice the chosen sheets, QC on a contact sheet, then wire the player/enemy animations into the Godot 2D DEEPFALL project. Do not write into a live game tree until staging is approved.

## Status since 2026-11-03 (updated 2026-11-14, loop wave W9)

What was staged above has since been cleaned, sliced, and wired — this section
records what actually happened, so the "STAGED ONLY" header above is history,
not current state.

- **Heroes:** the three starting classes were cleaned from the regen sheets
  and built into the game's procedural paper-doll rig
  (`build_pixel_hero.py` → `deepfall-game/assets/hero/`): tech soldier, red
  soldier, hooded mage — run / idle / jump / fall / land / crouch / dash
  poses, aimed tool swings with swing trails, verlet cape. The visible hero
  is the rig, not the sheet frames. The miner (03) did not become the
  player; the skeleton hero (16) is still a separate/unlockable hero, not a
  4th starting class.
- **Enemies:** six kinds redrawn as pixel art matching the hero
  (`build_pixel_enemies.py` → `deepfall-game/assets/enemies_px/`):
  cave-bat-swarm, miner-ghoul, rock-golem, cave-spider, ore-mimic,
  tunnel-worm — each with walk / attack frames, hit flash, squash,
  wind-up glow, and a 6-frame pixel death. See
  `staging/deepfall/ANIMATIONS.md` ("Live game" addendum) for the frame
  counts, including the W5 PROC frames (ore-mimic attack 4/4,
  tunnel-worm walk 3/3).
- **KayKit packs (separate source, CC0, 2026-11-13):** `kaykit-skeletons/`
  and `kaykit-dungeon-remastered/` (LICENSE.txt + MANIFEST.md in each).
  Skeleton Warrior became the 7th enemy (GLB baked to 2D in Blender
  headless: walk 4 / attack 4 / death 6 / idle 1, in the game tree at
  `assets/enemies_px/skeleton-warrior/`). The chest prop was wired in
  (1 hit, drops gold/torch); five more prop sprites (barrel, candle,
  banner, column, coins) are staged in the game tree at
  `assets/hero/props/` — textures only, not wired. In-game sighting of
  the warrior and chest is still unverified.
- **Multiframe sheets (`multiframe/`):** v2 walk/attack/climb/crouch/melee/
  swim sheets for heroes and enemies (miner, skeleton, hollow knight,
  hollow archer, fungal, ember, and more) — generated reference, not yet
  wired. Skit's hand-drawn homework stays his: PixiEditor projects
  (miner walk, skeleton walk — 4 poses each, in
  `multiframe/miner-walk-v2/` and `multiframe/skeleton-walk-v2/`) and
  Pencil2D projects (hollow knight + hollow archer walk, 1 missing
  opposite-contact pose each).
- **Still staged-only:** the 12 original sheets above as presentation
  sheets (backdrop/labels intact); the items/weapons/tiles/effects sets
  in `items*/`, `tiles*/`, `effects/` that were never wired as game
  content. The "Open decisions" above are settled for the player
  (three classes) and the six original enemies; slicing approach (b)
  — clean cells to transparency — is what was used.
