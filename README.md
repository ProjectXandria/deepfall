# DEEPFALL: Relics of the Below

Side-view 2D roguelike dungeon platformer — Terraria-style block
mining/crafting/construction plus WazHack-style systemic, lethal dungeon
crawling. Godot 4.8 beta 1, GDScript.

Game Off 2026 entry (theme: SHIFT). Build-and-submit deadline: Dec 1, 2026.

## Status

Merged 2026-11-15 (chunks 1–4, seed 20261101): Forgotten Mines, 200×90 world,
40 rooms, 138 ore veins, 3 starting classes (tech soldier, red soldier,
hooded mage) plus an unlockable skeleton hero (scythe, HP 90, melee 18),
10 enemies, chunk-streamed persistent world, save/reload, crafting,
3-hit mining with two crack stages, inner corners, slopes / half-blocks /
stairs, staged particle FX (ember, dust, spore, slash, explosion),
Effekseer orb (scale 2.0) and death effects, twin-stick touch controls,
pickaxe/sword tool selection, Terraria hotbar and hearts, WazHack message
log. Fungal Hollows is groundwork only (stub, no build).

## Open

Godot 4.8 beta 1 (editor + Android export templates). Open `project.godot`.
Android: export preset "Android (Debug)" with a debug keystore.

## Controls (Phase 11)

Touch (floating twin sticks — they appear wherever your thumb lands):
- Left half: MOVE stick (push down = crouch / drop through platforms, strong up-flick = jump)
- Right half: AIM stick — attack / mine in any direction you pull (hold to repeat, tap = attack ahead)
- JUMP (hold for higher jump, double jump), DASH, SLAM, SWAP tool
- Hotbar (top): pickaxe, sword/staff, torch, lantern, workbench (tap to equip / place)
- CRAFT, SAVE, NEW (tap twice) top-right

Desktop: A/D move, Space jump, Shift dash, F slam, mouse aim + hold LMB attack/mine,
J attack, Q / 1 / 2 tools, T torch, L lantern, B bench, C craft, F5 save, F9 new run.

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

## Current build

- v1.2 (code 3): `exports/deepfall-phase1-debug.apk`, 95,793,409 B,
  sha256 `dc8b73958957232b6005311e49e7a36bb43f28f2cd7b78c24d41280c7cdc1ea0`, apksigner PASS.
  Uploaded 2026-11-13 ~22:54 PST on Skit's tap; link expires Sun Nov 15 ~23:13 PST.
  This APK predates the chunk 1–4 merges and the "Phase 1" label fix — it
  still badges as "DEEPFALL Phase 1" and has the old 2-hit mining.
- Merged build 2026-11-15 ~22:00 PST (chunks 1+2+8 in live, label "DEEPFALL"):
  `exports/deepfall-v1.3-debug.apk`, 93,571,915 B,
  sha256 `2fb3b4f2d5a5bbc6a6d8453a4c9fc4467dad162de2d0fdacbaa62160413ade24`,
  apksigner v2+v3 PASS, zipalign OK. Selftest + P11 green on live (seed 20261101,
  rooms 40/40, ore_veins=87). NOT uploaded anywhere — delivery is Skit's call.
  Superseded 2026-11-15 ~15:16 PST: version bumped and rebuilt (see below).
- **v1.3 (code 4), rebuilt 2026-11-15 ~15:16 PST** on Skit's tap — `version/name`
  1.2 → 1.3, `version/code` 3 → 4 in `export_presets.cfg`, no code changes:
  `exports/deepfall-v1.3-debug.apk`, 93,571,915 B,
  sha256 `49f2815932229cd64e4711d39b98687007bdba3bfa7ffa31e1a8575bf6182f61`,
  apksigner v2+v3 PASS, zipalign OK, badging `versionName='1.3' versionCode='4'`.
  Export rc=0, 0 errors. Uploaded 2026-11-15 ~15:41 PST on Skit's tap:
  https://muse.ai/files/1409033565616215/4771379009816934/dbz6mtwyyzttltxu21s28lxd/deepfall-v1.3-debug.apk
  — link expires Mon Nov 17 ~15:33 PST.
- GitHub still at `103f450a` (Phase 13) — push is Skit's call, as is the Game Off entry pick
  (DEEPFALL vs Shiftworlds, deadline Dec 1, 2026 13:37 PST). Orb scale settled
  at 2.0 (chunk 3 merge, 2026-11-15).
- NOTE on the rename (2026-11-15): `config/name` is now "DEEPFALL", so the
  Android user-data folder moves from `DEEPFALL Phase 1` to `DEEPFALL`.
  Saves from the v1.2 APK will NOT carry over to the renamed build; the
  merged game starts fresh. Save format itself is unchanged (SAVE_VERSION 9,
  plus the new `cracked2` key, which old saves simply lack).
