# W5 — Close documented animation gaps, procedural only

Slug: `w5-animation-gaps`. Finished 07:41 PST 2026-11-13, ~24 min before
the 08:05 PST loop deadline. Status: DONE — merged to the live tree,
re-gated green on scratch and live.

## 1. What changed

### 1a. Ore-mimic attack 4th pose — PROC (new frame)

- New file: `assets/enemies_px/ore-mimic/attack_3.png` (26×26 RGBA).
- Built by `loop/phases/w5-animation-gaps/w5-build-frames.py`: attack_2.png
  (mouth closing, tongue out) translated +2 px toward the attack
  direction and +1 px down — a follow-through / recovery lunge after
  the bite. Integer translation: palette untouched, no pixel resampled.
- QC: 55% of pixels differ from attack_2, 48% from attack_0; eyeballed
  on a 8x contact sheet — the chest visibly surges forward and settles.
- `scripts/enemy.gd`: ore-mimic `"attack": 3 → 4`. Attack duration is
  now 4/8 = 0.5 s (was 0.375 s); the strike point is clamped to 60%
  of the duration (0.30 s), so damage still lands inside the animation.
  No balance change: same damage, same range, same cooldown.

### 1b. Tunnel-worm walk extra frame — PROC (new frame)

- New file: `assets/enemies_px/tunnel-worm/walk_2.png` (36×18 RGBA).
- Built by the same script: walk_1.png lifted 1 px (the body touches
  the bottom edge, so a sine offset needed headroom), then a
  per-column vertical sine offset (amplitude 1 px, one wave across the
  36 px body, phase-shifted) — a mid-slither phase between walk_0
  and walk_1.
- QC: 21% of pixels differ from walk_1, 34% from walk_0; eyeballed on
  a 8x contact sheet — the body undulates at a visibly different phase.
- `scripts/enemy.gd`: tunnel-worm `"walk": 2 → 3`. Walk cycle is now
  3 frames at 6 fps = 0.5 s (was 0.33 s). No speed change.

### 1c. Red/mage fall/land — REUSE, verified (no new frames)

- Finding: the visible hero is the procedural paper-doll rig
  (`scripts/hero_rig.gd`), which is class-agnostic. The fall flail
  (`vel.y > 0`, legs splay + flail) and the land squash (body_y = 2,
  scale 1.1x / 0.88y for 0.13 s) come from the animation state dict,
  not from per-class frames — so red and mage already reuse tech's
  fall/land poses by construction. The legacy `_anim_fall` frame sets
  in `player.gd` (tech 3, red 0, mage 0) feed a hidden sprite
  (`_sprite.visible = false`); they are not what the player sees.
- New test-only check in `_run_selftest_phase9` (`scripts/main.gd`,
  before the restore block): drives the rig directly per class with
  a falling state and a landing state and asserts the pose changes
  (fall: front-leg rotation |rot| > 0.05; land: scale.y < 2.9).
  Prints `DEEPFALL_SELFTEST_PHASE9 rig_fall_land` lines for tech,
  red, and mage. The BETA-REPORT "no fall/land frames" gap is now
  verified reuse, not an unverified claim.
- `staging/ANIMATIONS.md`: W5 section added with PROC/REUSE labels.

### 1d. What was NOT touched

- No new sprite generation (no image-gen calls, no new hand-drawn
  sheets). Skit's PixiEditor/Pencil2D homework is untouched.
- No Effekseer orb scale change. No gameplay balance, no map
  algorithm, no world-gen output. READY line must stay byte-identical
  (see §3).

## 2. Files changed (scratch → live)

- `scripts/enemy.gd` — STATS counts + comments only.
- `scripts/main.gd` — test-only Phase 9 rig check.
- `assets/enemies_px/ore-mimic/attack_3.png` (+ generated `.import`).
- `assets/enemies_px/tunnel-worm/walk_2.png` (+ generated `.import`).
- `~/workspace/asset-pipeline/staging/deepfall/ANIMATIONS.md` — W5
  section (staging file, outside the game tree; updated in place).

## 3. World identity

READY line (seed 20261101, scratch selftest + all live runs):
`DEEPFALL_PHASE1_READY seed=20261101 rooms=40/40 ore_veins=138
spawn=(10, 44) exit=(190, 42) connected=true` — byte-identical to the
pre-W5 invariant (scratch load_ms=1607).

## 4. Gates — scratch chain

`w5-gate-scratch-summary.txt` (chain 15:21:54–15:26:31 UTC, FAIL=0):

- selftest rc=0 errors=0 passfalse=0
- p11-tech rc=0 errors=0 passfalse=0 — sword 50→35, P14 1.50/110.7
- p11-red rc=0 errors=0 passfalse=0 — sword 50→30, P14 1.50/110.7
- p11-mage rc=0 errors=0 passfalse=0 — sword 50→38 (orb damage, W1
  fix holding), P14 1.50/110.7
- selftest-load rc=0 errors=0 passfalse=0 — VACUOUS (see §4a)

Phase 9 rig check lines (from w5-scratch-selftest.log, all PASS=true):

- `rig_fall_land class=tech fall_leg_rot=-0.28 land_scale_y=2.64`
- `rig_fall_land class=red fall_leg_rot=-0.34 land_scale_y=2.64`
- `rig_fall_land class=mage fall_leg_rot=-0.37 land_scale_y=2.64`
  (expect |rot| > 0.05, sy < 2.9 — all three pass; the fall rotation
  differs slightly per class only because the rig's flail phase at
  call time differs, not because the pose is class-specific.)

### 4a. The vacuous selftest-load flaw (W4 lesson, re-found)

The gate scripts delete the save before `--selftest-load`, so it
prints `DEEPFALL_SELFTEST_LOAD FAIL no save file found` and the
rc=0/passfalse=0 line is meaningless. Proper sequence run on
scratch after the chain: `--selftest` (creates save `selftest9`)
then `--selftest-load` with the save present —
`w5-scratch-selftest-load-proper.log`: rc=0 errors=0 passfalse=0,
`PASS=true` (pos/hp/ore true, Phase 7 true, Phase 8 class_ok=true).
Same proper sequence was run on live (§5).

## 5. Merge + live re-gate

Merged by explicit file copy only (scratch → live, verified
byte-identical after copy; `diff -rq scripts` clean):

- `scripts/enemy.gd`, `scripts/main.gd`
- `assets/enemies_px/ore-mimic/attack_3.png`
- `assets/enemies_px/tunnel-worm/walk_2.png`
- No `.import` files merged (see §7 — headless runs generate
  per-run import hashes; the editor import at export time creates
  the stable ones).

`w5-gate-live-summary.txt` (chain 15:29:04–15:34:28 UTC, FAIL=0):

- selftest rc=0 errors=0 passfalse=0
- p11-tech rc=0 errors=0 passfalse=0 — sword 50→35, P14 1.50/110.7
- p11-red rc=0 errors=0 passfalse=0 — sword 50→30, P14 1.50/110.7
- p11-mage rc=0 errors=0 passfalse=0 — sword 50→38, P14 1.50/110.7
- selftest-load rc=0 errors=0 passfalse=0 (vacuous, see §4a)
- selftest-load-proper rc=0 errors=0 passfalse=0 — PASS=true
  (pos/hp/ore true, Phase 7 true, Phase 8 class_ok=true)

READY line on live: byte-identical on every run (load_ms 1087–1395,
inside W4's post-opt live range 1009–1513).
No Godot process running at finish (the one pgrep hit was the
exec shell matching its own command line). No push, publish,
upload, APK, or link at any point.

Note on `pushed` variance: live tech pushed=7.6 and mage
pushed=−0.3, vs 15.8 / 11.7 on scratch — the knockback displacement
varies with the golem's spawn angle and the orb's strike direction;
the load-bearing numbers (golem hp 50→35 / 50→30 / 50→38) are exact
on both trees and the suite's own PASS=false count is 0. Not a
regression.

## 6. Verdict / open items

W5 DONE. All three BETA-REPORT section 4 animation gaps are closed
and merged: mimic attack 4/4 (PROC), worm walk 3/3 (PROC), red/mage
fall/land verified reuse (PROC rig, all classes). No open items from
this wave. What still needs Skit (unchanged): his hand-drawn
PixiEditor / Pencil2D sheets when he sends them, the Effekseer
orb-scale eyeball call, phone-feel verdicts, GitHub push, APK
re-upload.

## 7. Lesson (for W7)

- `--check-only --script` on a lone GDScript file reports bogus
  "Parse Error: Identifier DeepfallMapGen not declared" — the global
  class only resolves inside the project. It is not a syntax check
  for this tree; the gate run itself is the check.
- New PNGs need no hand-written `.import`: a headless game run
  imports them on the fly (10+ distinct per-run `.ctex` hashes for
  attack_3.png appeared in scratch `.godot/imported/` — the hashes
  are per-run, not stable). Do NOT hand-craft `.import` files; the
  editor import at export time (W7) creates the stable ones. The
  game runs green with PNGs alone, proven by both gate chains.
- The gate scripts' plain `--selftest-load` step is vacuous (it
  deletes the save first). Always run the proper sequence:
  `--selftest` then `--selftest-load` with the save present.
