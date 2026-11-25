# W7 — Final Verification + APK Rebuild — REPORT

**Wave:** `w7-final-verify` · **Date:** 2026-11-13/14 (gates + export run 2026-11-13 22:28–22:40 PST)
**Scope:** DEEPFALL only, refine-only, local only. Verify-only wave: no game code
was changed. No push, publish, submit, upload, or download link.
**Verdict: DONE — full gate chain green on the live tree (6/6 steps rc=0, 0 SCRIPT
ERRORs, 0 PASS=false), APK rebuilt from the W1–W6 tree and verified (v1.2, code 3,
apksigner PASS). Nothing was changed; nothing needed fixing.**

## Start state (verified on disk before running)

- Live tree = Phase 14b + W1–W6 merged. `loop/queue.json`: W1–W6 done, W7 pending.
  `loop/state.json`: `active=w7-final-verify`. No Godot running at spawn.
- `export_presets.cfg` already at **version/code=3, version/name="1.2"** (bumped by
  the KayKit thread, not by the loop) — so the rebuild is v1.2/code 3, not the
  v1.1/code 2 the original W7 brief expected. Reported as it is.
- Live tree also carries the KayKit additions from another thread (2026-11-13
  evening, live-only, NOT loop work): skeleton-warrior 7th enemy slug
  (`enemy.gd` + `main.gd` ENEMY_SLUGS, frames in `assets/enemies_px/skeleton-warrior/`)
  + chest prop (`phys_prop.gd` + `main.gd` prop kinds). Included in the rebuild
  as they stand; verified present in the APK (see below). Not removed, not modified.

## Gates (live tree, solo sequential, xvfb, 2400×1080, seed 20261101)

Gate script: `w7-gate.sh` (fails a step on rc!=0, any SCRIPT ERROR, or any
PASS=false — the W3/W4 harness rules). Summary: `w7-gate-summary.txt`.
Chain finished 2026-11-14T06:39:22Z.

| Step | rc | SCRIPT ERRORs | PASS=false | READY (seed 20261101) | Notes |
|------|----|---------------|------------|------------------------|-------|
| `--selftest` | 0 | 0 | 0 | rooms=40/40 ore=138 spawn=(10,44) exit=(190,42) connected=true, load_ms=1697 | Phases 6–10 all PASS |
| `--selftest-load` (proper sequence, right after selftest) | 0 | 0 | 0 | same, load_ms=1733 | `PASS=true` pos/hp/ore true; Phase 7 `PASS7=true`; Phase 8 `class_ok=true` (mage) |
| `--selftest-p11 --class=tech` | 0 | 0 | 0 | same, load_ms=1488 | sword 50→35, pot true loot 1, dash 146.0, hp 100, P14 1.50/110.7, `ENEMY_SPAWNS total=26` |
| `--selftest-p11 --class=red` | 0 | 0 | 0 | same, load_ms=3202 | sword 50→30, pot true loot 1, dash 146.0, hp 120, P14 1.50/110.7 |
| `--selftest-p11 --class=mage` | 0 | 0 | 0 | same, load_ms=1522 | sword 50→38 (orb, `ORB_FIRED` ×2), pot true loot 1, dash 146.0, hp 80, P14 1.50/110.7 |
| `--soak --soak-secs=180` tech | 0 | 0 | 0 | same, load_ms=1275 | see soak section |

**READY line seed 20261101 is byte-identical on every run** — the invariant held
through the whole loop (Phase 14 → W7). `load_ms` 1275–3202 across the chain is
sandbox CPU noise (W6 saw 1390–6579 on identical seeds); not a phone number.

Non-fatal log noise (known sandbox artifacts, not game errors): `ERR_CANT_OPEN`
(ALSA, no audio device in sandbox) once per run; "3 resources still in use at
exit" on some runs (Godot shutdown artifact). 0 SCRIPT ERRORs, 0 PASS=false in
every log.

### Soak (180 s, seed 20261101, tech)

`SOAK_DONE t=180 deaths=0 stuck=5 kills=0 mined=0 rooms=3 climb=27 deep=56
fps_min=1 fps_avg=5 foes0=70 foes0max=50 near0=180`

- Stuck events (all in the known fall-shaft cluster, seed 20261101, same as W6):
  t=16 (26,46), t=37 (24,54), t=98 (24,56), t=110 (24,54), t=137 (22,47).
  The bot always got out (climb 27 rows; ended at (24,32), hp 100, mobile).
- Rooms visited: 0 → 4 → 2 (3 rooms). `near0=180` — no foe within the bot's
  280 px radius for the whole run (same no-combat pattern as W6 S1/S4/S5:
  the bot random-walks and never seeks foes; kills=0 is a bot artifact, not
  a combat finding). `foes0max=50 s` — well under W6's 120 s named-finding
  threshold.
- fps 1–7 under the sandbox software renderer — not phone fps.

## APK rebuild

- **Old file replaced:** `exports/deepfall-phase1-debug.apk` was the KayKit v1.2
  build from 2026-11-13 ~22:13 PST — **95,772,929 B, sha256
  `8a3b8f2c12fbf8a0acefef808e2c9777c147d4166cf05fe4000c2336dcf92b71`**.
  Preserved byte-identical as `exports/deepfall-v1.2-kaykit-backup.apk`
  (that build's download link expires Sun Nov 15 ~22:22 PST; the backup keeps
  the file on disk). The v1.1 backup (`exports/deepfall-v1.1-backup.apk`,
  94,725,129 B) was untouched.
- **Export:** headless `--export-debug "Android"`, Godot 4.8 beta 1, exit 0 in
  ~47 s. Log: `w7-export.log` — **0 lines matching ERROR / Failed / missing**.
  No editor-import segfault this time (import cache already warm).
- **New APK:** `exports/deepfall-phase1-debug.apk`, **95,793,409 B**,
  sha256 **`dc8b73958957232b6005311e49e7a36bb43f28f2cd7b78c24d41280c7cdc1ea0`**,
  mtime 2026-11-14 06:40 UTC (2026-11-13 22:40 PST).
- **aapt2 badging:** `package: name='com.dogbyte.deepfall' versionCode='3'
  versionName='1.2'`, label "DEEPFALL Phase 1", min SDK 24 / target 36.
- **apksigner verify:** v2 scheme true, v3 scheme true, 1 signer. **PASS.**
- **KayKit assets inside the APK (verified by `unzip -l`):**
  - skeleton-warrior: 15 `assets/enemies_px/skeleton-warrior/*.png.import`
    entries (walk 4 + attack 4 + death 6 + idle 1 — exactly the frames
    `enemy.gd` loads at runtime) plus 24 entries under `assets/enemies/
    skeleton-warrior/` (the staged non-px copy).
  - chest: `assets/hero/props/chest.png.import` + imported
    `chest.png-<hash>.ctex` texture.
  - 671 `.ctex` textures total in the APK; export log shows no
    missing-resource errors for the new assets.
- **NOT uploaded, NO download link created** — that needs Skit's word.

## What changed

**Nothing.** No game code, no test code, no assets were modified in this wave.
The live tree at W7 close is exactly the tree W6 left (Phase 14b + W1–W6 +
KayKit additions). The only file writes were: the new APK (replacing the
KayKit v1.2 build, which is backed up), the W7 gate/export logs, this report,
the new digest, and the queue/state bookkeeping.

## Known open items (not fixed here — out of W7's verify-only scope)

- **`--selftest-p11` with NO `--class` stalls after READY in this sandbox**
  (W6 finding, still present by report: a 45-min solo run killed by timeout,
  plus earlier runs, 0 SCRIPT ERRORs — a test-harness stall, not a game
  crash). Per-class gates (tech/red/mage) all complete and green, so each
  class is verified individually; only the single-command all-classes form
  is unverified. NOT diagnosed or fixed in this wave, per the brief.
- **In-game sighting of skeleton-warrior spawn/kill and chest break is still
  unverified** (KayKit thread's open item; the gates prove the frames and
  prop load, not that Skit has seen them in play).
- Phase 6 `a3` timing flake did not appear in this wave; not chased.
- W1 observation, unchanged: a perfectly horizontal mage orb sails 4 px over
  a floor-level pot's hit rect.

## What the gates could NOT prove

- Sandbox fps (1–7, llvmpipe) and `load_ms` (1275–3202, host-noise) are not
  phone numbers. S25 frame rate, input feel, and startup-lag feel are still
  Skit's verdict.
- The soak bot random-walks, never seeks foes, never aims, never chooses to
  climb. Its stuck/kills/mined numbers are lower bounds on what the game
  supports, not measurements of play.
- The gates prove the APK installs' contents and signature, not that it
  installs cleanly over the v1.2 on Skit's phone or what it looks like there.

## Left for Skit

- Orb-scale call (Effekseer mage orb 1.0 vs 2.0) — untouched, still his.
- Phone-feel verdicts: deep-cave density, climb-out comfort, startup feel,
  S25 fps; in-game sighting of skeleton-warrior + chest.
- GitHub push (still at `103f450a`) — Phase 14 + 14b + beta edits + W1–W6 +
  KayKit additions, all local.
- APK re-upload / download link — the rebuilt v1.2 APK is on disk, NOT
  uploaded; the KayKit v1.2 link (expires Nov 15 ~22:22 PST) still points at
  the pre-W6 build.
- Game Off entry pick (DEEPFALL vs Shiftworlds), AI-disclosure level —
  deadline Dec 1, 2026, 13:37 PST.

## Files

- Gate script: `loop/phases/w7-final-verify/w7-gate.sh`
- Logs: `w7-gate-summary.txt`, `w7-gate-selftest.log`,
  `w7-gate-selftest-load.log`, `w7-gate-p11-tech.log`,
  `w7-gate-p11-red.log`, `w7-gate-p11-mage.log`,
  `w7-gate-soak-tech-180s.log`, `w7-export.log`
- APK: `exports/deepfall-phase1-debug.apk` (new) +
  `exports/deepfall-v1.2-kaykit-backup.apk` (old build preserved)
- Digest: `loop/DIGEST-2026-11-14.md`
