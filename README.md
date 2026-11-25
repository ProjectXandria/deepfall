# DEEPFALL: Relics of the Below

Side-view 2D roguelike dungeon platformer — Terraria-style block
mining/crafting/construction plus WazHack-style systemic, lethal dungeon
crawling. Godot 4.8 beta 1, GDScript.

Game Off 2026 entry (theme: SHIFT). Submission deadline: Dec 1, 2026
13:37 PST. DEEPFALL is the entry.

## Status — v2.1 (2026-11-23)

Live: 200×450 world (seed 20261101), 195 rooms, 653 ore veins, 65 traps,
~490 foes. Five depth biomes: Shallows (0–30), Fungal Hollows (30–100),
Crystal Depths (100–230), Ember Deep (230–370), Boss arena (370–450).
Straight-down dig time, measured: 243.4 s touch / 212.0 s keyboard.

- 3 starting classes (tech soldier, red soldier, hooded mage) plus an
  unlockable skeleton hero (scythe, HP 90, melee 18, unlocks on first
  extraction).
- 15 enemies across the biomes, from cave bats and slimes up top to
  ember imps, lava hounds, and ash wraiths down deep.
- Two bosses, one per run, picked at random (seed % 2): the Relic
  Warden golem and the Quaternius dragon, both 300 HP, fought in a
  gated 24×10 arena at the bottom (gate seals behind you; re-mineable
  out, no soft-lock). Both drop amber 3 + gold 2 + stone/coal 2.
- SHIFT (theme): the world flips between Amber and Void on one button
  (TAB or on-screen SHIFT, 0.35 s cooldown). 645 gated cells (amber
  289, void 356): 233 platforms and 411 amber ore veins exist in one
  world only, and the exit only works in Void.
- Full inventory panel (36-item catalog): use food and potions, wear
  rings, place torches, lanterns, and workbenches. Burden system slows
  you down when your pack gets heavy. Selftest 9/9.
- WazHack systems 1–8: hunger clock (0.2/s), identification +
  blessed/cursed loot, traps, shops/altars/fountains, talents, pets,
  polymorph (rare), 43 rumours. Selftest 18/0.
- Rock gets harder with depth (fungal 3 hits, crystal 5, ember 6,
  boss-rock 8); ore bands are depth-banded (gold, then amber).
- Performance: foe spawns stagger (max 3/frame), autosave on a 15 s
  dirty-only timer (a crash can lose up to ~15 s), spawn table indexed
  by chunk, FPS overlay on by default (MENU → SETTINGS, or F8) with a
  frame graph and chunk-crossing markers.
- Grey-block fix: base art is frozen at generation (no more
  neighbour-mask blanks); shaft flat-grey pixels down to 0.
- Chunk-streamed persistent world, save/reload, crafting, cooking,
  inner corners, slopes / half-blocks / stairs, staged particle FX
  (ember, dust, spore, slash, explosion), Effekseer orb (scale 2.0)
  and death effects (PNG fallbacks on web, where Effekseer has no
  wasm32 library), Terraria hotbar and hearts, WazHack message log.

Saves: SAVE_VERSION 10. v1.7 saves do NOT carry (v1.7 was version 9);
v1.8 and later saves do carry.

## Open

Godot 4.8 beta 1 (editor + export templates). Open `project.godot`.
Export presets: "Android (Debug)" (debug keystore) and "Web"
(nothreads build, no COOP/COEP headers needed; playable on itch.io).

## Controls

Touch (on-screen buttons):
- JUMP (hold for higher jump), DASH, SLAM, DROP, SWAP tool
- SHIFT to flip Amber/Void, plus USE, CRAFT, INV, SAVE, NEW, MENU,
  TALENT
- Hotbar (top): pickaxe, sword/staff, torch, lantern, workbench
  (tap to equip / place)
- Hold on a block to mine it, tap a foe to attack

Desktop: A/D move, Space jump, Shift dash, F slam, mouse aim + hold
LMB attack/mine, J attack, Q / 1 / 2 tools, T torch, L lantern,
B bench, C craft, I inventory, TAB shift worlds, F8 FPS overlay,
Down + jump to drop through a platform, F5 save, F9 new run.

## Phase 11 (graphics, physics, controls)

- Terraria-style pixel paper-doll hero per class (`build_pixel_hero.py` -> `assets/hero/`),
  procedural run / idle / jump / fall / land / crouch / dash poses, aimed tool swings with
  swing trails, verlet cape.
- Physics: acceleration + friction, variable jump height, apex hang, real knockback for
  player and enemies (wall bounce), pushable crates / rolling barrels, breakable pots with
  loot, props fall and crush enemies, ground slam shockwave.
- Juice: block debris, hit flash, damage numbers, pickup flyers, screen shake, hit-stop.
- Self-test: `godot -- --new-run --selftest-p11` (simulated multi-touch session).

## Phase 12 (enemy art, control settings, sound)

- All six enemies redrawn as pixel art matching the hero (`build_pixel_enemies.py` ->
  `assets/enemies_px/`), with distinct walk / attack frames, hit flash, squash and wind-up glow.
- MENU -> Controls & Feel: stick size, button size, opacity, sound volume, vibration,
  left-handed (mirrored) layout, MOVE BUTTONS drag editor, RESET. Saved to
  `user://deepfall_settings.json`; the game pauses while the menu is open.
- Procedural SFX (`build_sfx.py` -> `assets/sfx/`): swing, mine hit/break, hit, hurt, jump,
  land, dash, slam, pickup, prop break, enemy death. Phone vibration on hits, mining,
  slams and damage (Android VIBRATE permission enabled in the export preset).

## Phase 13 (death animations, loot, persistence, run card, ambience)

- Each enemy has its own 6-frame pixel death (flash, species motion, dissolve) played by a
  falling corpse (`enemy_corpse.gd`); drops are physical bouncing pickups with a magnet (`loot_drop.gd`).
- Smashed props stay gone and pushed props keep their place across save / reload.
- Run summary card on death and extraction (depth, kills, ore, blocks, props, deaths, loot)
  with SHARE (saves a PNG of the card + copies brag text) / KEEP DIGGING / NEW RUN.
- Looping cave ambience (`build_ambience.py`): drone, drips, rumbles; deeper = lower drone and
  louder rumbles. "Cave ambience" volume slider in MENU.

## Phase 14 (phone playtest fixes, 2026-11-06)

Skit's first real-phone playtest was on the Phase 10 build (screenshot fingerprint), but all
three complaints were fixed as asked:

- JUMP: quick taps gave a ~34 px hop that read as a dead button (variable jump height).
  `jump_btn_full` — JUMP-button taps give a full jump; stick-flick jumps keep variable height.
  Verified: real_touch_jump rose=110.7 at phone geometry (scale 1.50).
- Maps: 80×45 / 14 rooms → 200×90 / 40 rooms, fresh random seed every run, same structured
  room+corridor algorithm + flood-fill validation. Floor guard under the spawn/exit anchor.
  SAVE_VERSION 8→9 (v8 saves ignored by design).
- Startup: loading screen ("DIGGING THE MINES…") + staged rebuild; `load_ms` on READY.
- Anchor, unchanged through every wave since: `DEEPFALL_PHASE1_READY seed=20261101 rooms=40/40
  ore_veins=138 spawn=(10, 44) exit=(190, 42) connected=true`.

## Phase 14b (hint rings out + version bump, 2026-11-06)

- Fixed hint rings removed from `_draw_sticks` — sticks float to the thumb, no rings.
- `version/code` 1→2, `version/name` 1.0→1.1. APK v1.1 preserved as
  `exports/deepfall-v1.1-backup.apk`.

## Improvement loop (2026-11-12 → 2026-11-14, refine-only, local only)

Per-wave reports: `loop/phases/w*/REPORT.md`. Digests: `loop/DIGEST-2026-11-13.md`,
`loop/DIGEST-2026-11-14.md`.

- W1: mage P11 orb-wait + soak mine-upward (test-only). W2: deep-cave +1 foe (row > 60).
- W3: climb-out ledges in every shaft (climb probe 10 rows × 3 seeds; soak climb 36 live).
- W4: startup merge, world byte-identical, load_ms roughly halved in the sandbox.
- W5: animation gaps, PROC only (ore-mimic attack 4/4, tunnel-worm walk 3/3).
- W6: long soaks 600 s × 3 seeds, 0 deaths; fixed the seed-91838678 39/40-rooms map bug.
- W7: final verify 6/6 green + APK rebuilt v1.2/code 3.
- W8: `--selftest-p11` no-class stall does NOT reproduce (8/8 pass); fixed a real harness bug
  (stale run-card state let 12 checks read 0 while exit 0).
- W9: general fix — `_rebuild_world` clears all run-card state at entry (FAIL-pre 3-arm probe
  → PASS-post; death→card→respawn→extract regression green); docs refresh.

## KayKit additions (2026-11-13, CC0, local only)

- Skeleton Warrior, 7th enemy (walk 4 / attack 4 / death 6 / idle 1, hp 25, speed 80, dmg 8).
- Chest prop (1 hit, drops gold/torch). Five more prop sprites staged in `assets/hero/props/`,
  textures only, not wired. In-game sighting of warrior + chest still unverified.

## Later waves (2026-11-19 → 2026-11-23)

- WazHack systems 1–8 + asset wave merged 2026-11-19 (roster 10→15,
  5 KayKit props, 24 tile variants v4–v7, 9 resource icons, 4 klad FX).
- Playtest fix wave merged 2026-11-21 (grey blocks, neighbour-mask art,
  map variance, H 90→140, 4 s hint toast, SAVE_VERSION 9→10).
- Depth + biomes + boss merged 2026-11-21 (H 140→450, 5 biomes,
  32 new tiles, both bosses, digtime 243.4 s touch measured).
- Perf fix merged 2026-11-21 ~18:56 PST (stagger spawns, 15 s autosave,
  chunk-indexed spawn table, FPS overlay; crossing hitch 62 ms → 0.00 ms
  on the merged tree, worst walk frame 1233 ms → 343 ms).
- Shift I merged 2026-11-22 (TAB/button world-flip, 645 gated cells,
  exit only in Void).
- Inventory merged (9/9 selftest, 36-item catalog, burden system).
- Grey-blocks fix merged 2026-11-23 ~21:43 PST on Skit's option-b word
  (main.gd only; shaft flat-grey px 0, WazHack 18/0, Inventory 9/9,
  0 script errors).
- Web export verified 2026-11-24 (scratch-copy export rc=0, played in
  real Chromium; save persists across reload via IndexedDB) and built
  from live 2026-11-25 (release export, 9 files, 68,995,917 B;
  `exports/deepfall-web.zip`, 45,142,564 B, itch-ready).

## Current build

- **v2.1 (code 12), built 2026-11-23 ~21:43 PST** on Skit's tap —
  `exports/deepfall-v2.1-debug.apk`, 97,542,534 B,
  sha256 `90c77dcb…`, apksigner v2+v3 PASS, zipalign OK, same cert as
  v2.0 (installs over). Web export `exports/deepfall-web.zip`,
  45,142,564 B, sha256 `93f8939d…`, built 2026-11-25 ~00:06 PST.
  GitHub main @ v2.1 (pushed 2026-11-25 on Skit's tap).
- v1.7 (code 8), built 2026-11-19 ~14:54 PST on Skit's tap ("Build v1.7 with
  the asset wave") — `version/name` 1.6 → 1.7, `version/code` 7 → 8 in
  `export_presets.cfg`, no other live changes; live = v1.6 code + WazHack 1–8 +
  asset wave. Verify GREEN (import/selftest/P11 rc=0, rooms 40/40, WazHack 18/0,
  P11 hp=100 props=77, 0 script errors):
  `exports/deepfall-v1.7-debug.apk`, 95,992,511 B,
  sha256 `15ac207368136dd0434a42bcbb84e5d5a384fee306119fec2db15c28224e8ad7`,
  apksigner v2+v3 PASS, zipalign OK, badging `versionName='1.7' versionCode='8'`.
  GitHub main was @ `449e3026` (parent `b6785e1d` v1.6), 2,696 files.
- NOTE on the rename (2026-11-15): `config/name` is now "DEEPFALL", so the
  Android user-data folder moves from `DEEPFALL Phase 1` to `DEEPFALL`.
  Saves from the v1.2 APK will NOT carry over to the renamed build; the
  merged game starts fresh. Save format itself is unchanged (SAVE_VERSION 9,
  plus the new `cracked2` key, which old saves simply lack).

## Open items (Skit's calls)

- Relic spine (WazHack system 9, scoped, NOT built): (a) optional
  true-win on top of extract (recommended) vs (b) relic as the only win.
- Ore economy down ~35–45%? 3-hit mining revert? Dig-time floor
  (accept 4.1 min analytic or push higher)? Biome names/palette review?
  Boss-rock v0–v6 distinctness? Path overlay art may read as a hole?
- Fungal Hollows is groundwork only (stub, no build). Lighting/grading
  scoped (~1 session + S25 eyeball).
- No license file is set on this repo (jam rules don't require open
  source; the choice is Skit's).
