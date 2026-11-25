# W9 — Card-state hardening (`_rebuild_world`) + docs refresh

**Wave:** w9-card-state-hardening-docs-refresh · **Date:** 2026-11-14
**Scope:** DEEPFALL only, refine-only, local only. No new features, no Fungal
Hollows, no GitHub push, no APK upload, no download link. Effekseer orb
scale untouched (Skit's call).
**Verdict: DONE** — Part A merged to live and re-gated 6/6 green; Part B
docs merged in place. Nothing pushed, published, or uploaded.

## Part A — harden `_rebuild_world`

### Root cause

`_rebuild_world(use_save, staged)` (`scripts/main.gd` ~557) resets run state
(ore, inventory, kills, `extracted=false`, `_deaths`, `_run_time`, …) but
never touched run-card state:

- `_card_pending` / `_card_reason` — armed by `player_died()` (0.9 s,
  reason `"death"`) and by the exit-reach check in `_process` (0.4 s,
  reason `"extract"`); `_process` counts `_card_pending` down and calls
  `show_run_card(_card_reason)` at 0. `show_run_card` is the only pauser
  (`paused=true`).
- `_card_open` — a card left open across a rebuild keeps the tree paused
  in the fresh world.
- `_respawn_timer` — `_close_run_card` re-arms a 0.05 s respawn when the
  player is dead; `player_died()` arms 1.2 s when cards are disabled.
  A stale timer fires `respawn_run` in the fresh world and teleports the
  player back to spawn.
- `player.dead` — the no-save branch of `_rebuild_world` sets
  `player.position` / `player.hp` directly instead of calling
  `player.respawn_at()` (which is the only path that clears `dead`), so a
  dead player stays dead in the fresh world and ignores input
  (`player.gd` `_physics_process` early-returns while dead).

W8 proved the same stale state through the *suite* (12 checks read 0 while
the process exited 0) and fixed it only at `_run_selftest_p11` entry
(live `main.gd` ~4660). The general hole — `_rebuild_world` itself — was
still open, and it bites every caller, not just the suite: `_ready`,
`new_run()`, the selftests, the soak, and the p11/p13 probes.

### FAIL-pre proof (scratch, before the fix)

Probe: `_run_probe_card_rebuild()` (scratch-only, `_ready` hook
`--probe-card-rebuild`), launched with the W8 exit-force save installed
(seed 91838678, player on the exit cell, `extracted=false`) so `_ready`'s
staged rebuild arms the card — the W8-style repro, aimed at
`_rebuild_world` itself. Run `probeA-nofix`, log `w9-probeA-nofix.log`:

| Arm | Result | Evidence |
|---|---|---|
| A — pending card through a fresh rebuild | **FAIL** | probe start `pending=0.27 open=false paused=false dead=false pos=(12064.0, 4503.99) reason=extract` (armed during `_ready`, exactly as W8 described; `DEEPFALL_EXTRACT_REACHED` printed before READY); after `_rebuild_world(false)` + 1.5 s: `pending=-0.09 open=true paused=true reason=extract` — the stale card opened in a fresh world where the player never reached the exit. |
| B — stale respawn timer | **FAIL (verdict label was the bug)** | `timer_armed=1.20`, `DEEPFALL_PLAYER_RESPAWN` printed — the stale timer DID fire and teleported the player back to spawn. The probe's verdict logic said PASS because pos (416.0, 4375.99) vs spawn (416.0, 4384.0) is 8.01 px apart and the threshold was < 2.0. Threshold fixed to < 16.0 after this run. |
| C — stale `player.dead` | **FAIL** | `dead_after_rebuild=true touch_move=1.00 dx=0.0` — the stick moved but the dead player doesn't move. |

READY on this run: `seed=91838678 rooms=40/40 ore_veins=139 spawn=(6, 68)
exit=(188, 70) connected=true load_ms=1963`.

Lesson recorded: a respawned player settles ~8 px above the exact spawn
point under gravity, so position-based respawn detection needs a ≥ 16 px
threshold, not 2 px; the `DEEPFALL_PLAYER_RESPAWN` log line is the
definitive check.

### Fix

`scripts/main.gd`, top of `_rebuild_world`, before `_clear_dynamic()` —
**16 lines of game code** (live lines 558–577, identical in scratch):

```gdscript
if _card_open:
    _close_run_card()
_respawn_timer = 0.0
_card_pending = 0.0
_card_reason = ""
player.dead = false
```

Ordering matters: the timer zeroing must come **after** the close, because
`_close_run_card` re-arms a 0.05 s respawn when the player is dead.
Closing an open card first also unpauses the tree (`show_run_card` is the
only pauser). A comment at the site records the W8/F2 provenance and the
three probe arms. No other file changed for Part A (`map_gen.gd` untouched,
verified identical live vs scratch).

### PASS-post proof (same repro, same launch state)

Run `probeA-fixed`, log `w9-probeA-fixed.log` — **3/3 PASS**:

| Arm | Evidence |
|---|---|
| A | `pending=0.00 open=false paused=false reason=` after rebuild (probe start pending was 0.28 — armed during `_ready` after the rebuild-top clear, then cleared by the probe's rebuild, confirming placement semantics). |
| B | `timer=0.00`, pos stayed at (916.0, 4567.99) — fell from the teleported spot, never teleported back; no `DEEPFALL_PLAYER_RESPAWN` in the log. |
| C | `dead_after_rebuild=false touch_move=1.00 dx=45.7`. |

READY: `seed=91838678 rooms=40/40 ore_veins=139 spawn=(6, 68) exit=(188, 70)
connected=true load_ms=1560`.

### Subsumption: does the general fix replace the W8 suite-entry clear?

Experiment: remove the W8 suite-entry clear on scratch only (backup
`/tmp/w9-main-with-w8clear.gd`; the live tree always carried the clear, so
the authoritative copy was never at risk), then run the exact W8 F2 repro —
`--seed=91838678 --selftest-p11` no-class, exit-force save installed.
Run `f2-noclass-noclear`, log `w9-f2-noclass-noclear.log`:

**All 12 anchors green with the W8 clear removed** — loot 1 / corpse
gone, move 1.00 / dx 96.2, jump rose 110.7, knockback 124.0, mine 3→0,
sword 50→35, crate 50.1, pot true / loot 1, dash 146.0, slam 20→10, menu
panel=true paused=true, P14 scale 1.50 / rose 110.7. **The general fix
provably subsumes the W8 clear.**

**Decision: KEEP the W8 suite-entry clear anyway** (defense in depth).
The clear is 6 lines, test-scoped only, zero cost, and it protects the
suite if `_rebuild_world` is ever refactored. The W8 block was restored on
scratch from the backup and verified present in both live and scratch
(`main.gd` ~4660); the live↔scratch `main.gd` diff after merge is exactly
two hunks: the `_ready` probe hooks and the probe functions — probes only.

### Regression proof: death → card → continue still works

Probe: `_run_probe_card_death()` (scratch-only, `--probe-card-death`),
fresh world, seed 20261101. Run `probeDeath-fixed2`, log
`w9-probeDeath-fixed2.log` — **all three lines green**:

```
DEEPFALL_W9_PROBE death card_open=true paused=true reason=death
DEEPFALL_W9_PROBE after_close dead=false paused=false at_spawn=true hp=100
DEEPFALL_W9_PROBE extract card_open=true paused=true reason=extract
```

(`DEEPFALL_PLAYER_RESPAWN` printed between death and the after-close line.
The first run of this probe showed `at_spawn=false` with dead=false,
paused=false, hp=100 — the respawn happened but the player had settled
~8 px off the exact spawn point during the 0.5 s wait; the threshold was
corrected to < 16 px, same settle as arm B. The re-run reads clean.)

On live, the same flow is covered by the existing `_run_selftest_p13_pre`
section 4 deliberate-death test (death → card → close → respawn), which
ran green inside the live `--selftest` below — the probe code itself is
scratch-only by design and was never merged.

### Gates

Full 6-step chain on scratch (`w9-gate-scratch.sh`, log
`w9-gate-scratch-chain.log`, summary `w9-gate-scratch-summary.txt`) and
again on live after merging (`w9-gate-live.sh`,
`w9-gate-live-chain.log`, `w9-gate-live-summary.txt`). Every step: rc=0,
0 SCRIPT ERRORs, 0 PASS=false, p11 values OK, READY anchor byte-identical.

| Step | Scratch load_ms | Live load_ms |
|---|---|---|
| `--selftest` | 2063 | 2131 |
| `--selftest-load` (proper sequence) | 1890 | 1384 |
| `--selftest-p11 --class=tech` | 2430 | 1382 |
| `--selftest-p11 --class=red` | 1429 | 1533 |
| `--selftest-p11 --class=mage` | 2121 | 1853 |
| `--selftest-p11` (no-class) | 1697 | 2182 |

Anchor on every run, both trees:
`DEEPFALL_PHASE1_READY seed=20261101 rooms=40/40 ore_veins=138 spawn=(10, 44) exit=(190, 42) connected=true`.

Live p11 values (all match the W7/W8 anchors): tech sword 50→35, red
50→30, mage 50→38, no-class 50→35; pot true / loot 1; dash 146.0; slam
20→10; P14 scale 1.50 / rose 110.7.

## Part B — docs refresh (docs only)

Four files brought current; every change is an addition, zero lines removed
from any existing content. Honesty labels (PROC/REUSE/SOURCE/SYNTH) kept;
no coverage claim invented — only what the gates actually proved.

| File | What changed |
|---|---|
| `deepfall-game/PHASE1-README.md` (+131 lines) | Top pointer to the current state + a dated appendix "Phases 11–14, hard beta, and the improvement loop (2026-11-05 → 2026-11-14)": P11–13 summary, Phase 14 (jump / maps / startup, with the Phase-10-build fingerprint note), 14b, hard beta + class variants + `_share_card` guard + soak, loop W1–W9 table with gate numbers, KayKit additions, v1.2 APK facts, updated "Honest limits". |
| `deepfall-game/README.md` (+52 lines) | Phase 14, 14b, improvement-loop (W1–W9 short table), KayKit additions, and a "Current build" section (v1.2, 95,793,409 B, sha `dc8b7395…`, link expiry, GitHub still at `103f450a`). |
| `~/workspace/asset-pipeline/staging/deepfall/MANIFEST.md` (+46 lines) | New section "Status since 2026-11-03": heroes cleaned/sliced into the rig, six enemies redrawn into `assets/enemies_px/`, KayKit packs as a separate CC0 source (skeleton-warrior wired, chest wired, five props staged-only), multiframe v2 sheets + Skit's hand-drawn homework, what is still staged-only. The "STAGED ONLY" header above it is now history, not current state. |
| `~/workspace/asset-pipeline/staging/deepfall/ANIMATIONS.md` (+19 lines) | New addendum "Live game (2026-11-13)": 7 live enemy kinds with real pixel frames, skeleton-warrior frame counts (KayKit bake), the hero as the procedural rig, and the note that W6–W9 changed no animation. |

Verified facts used in the docs: 7 enemy kinds in `scripts/enemy.gd`
(cave-bat-swarm, miner-ghoul, rock-golem, cave-spider, ore-mimic,
tunnel-worm, skeleton-warrior); skeleton-warrior 15 PNGs (walk 4 / attack
4 / death 6 / idle 1); chest in `scripts/phys_prop.gd` (KayKit bake, CC0,
1 hit); `export_presets.cfg` version/code=3, version/name="1.2".

## Merge record

- `scripts/main.gd`: surgical edit on live (fix block only) — NOT a whole-
  file copy, because scratch carries the probe code. Fix block verified
  byte-identical live vs scratch (20 lines, python-extracted comparison).
  Live↔scratch `main.gd` diff is exactly two hunks (probe hooks +
  probe functions). No probe code, no SUBSUMPTION marker, in live.
- `PHASE1-README.md`, `README.md`: explicit `cp` from scratch (diffs
  showed additions only); verified identical to scratch after copy.
- Staging `MANIFEST.md`, `ANIMATIONS.md`: explicit `cp` from the wave-dir
  drafts; verified identical to the drafts after copy.
- Pre-wave save restored: `w9-save-backup-pre-wave.json` copied back to
  `~/.local/share/godot/app_userdata/DEEPFALL Phase 1/deepfall_save.json`
  (seed 20261101, hp 100 — the W7 soak save).

## What the gates could NOT prove

- **Phone feel.** All numbers are sandbox (llvmpipe fps 1–7, load_ms
  1382–2430). The fix changes no game-visible behavior — it only clears
  stale state at rebuild — but the death→card→continue flow on a real
  phone is still Skit's verdict, along with the standing v1.2 verdicts
  (install/art, skeleton-warrior sighting, deep-cave density, climb-out
  comfort, startup feel).
- **The `_cards_enabled=false` window noted during W9.** In
  `--selftest`/`--selftest-load` modes `_cards_enabled=false` is set
  AFTER `_ready`, so a launch save standing on the exit cell can arm
  `_card_pending` during the staged rebuild's awaits, and the countdown
  block in `_process` does not re-check `_cards_enabled` — the card could
  open mid-selftest. The gate sequence never launches with such a save, so
  it has never fired in practice; the W9 fix now clears it at the next
  rebuild, but the arming window itself is out of scope and unreproduced.
- **Subsumption backup is ephemeral.** `/tmp/w9-main-with-w8clear.gd` may
  vanish on VM replacement; it is not needed — the live tree carries the
  W8 clear, and the subsumption evidence is in `w9-f2-noclass-noclear.log`.

## Anything left for Skit

- Nothing new from this wave. Standing items: Effekseer orb scale 1.0 vs
  2.0 (his eyeball call), GitHub push (still `103f450a`), Game Off entry
  pick (DEEPFALL vs Shiftworlds; deadline Dec 1, 2026 13:37 PST), v1.2
  phone verdicts (link expires Sun Nov 15 ~23:13 PST — re-upload only on
  his word), in-game skeleton-warrior / chest sighting.

## Files

Wave dir `loop/phases/w9-card-state-hardening-docs-refresh/`:

- `REPORT.md` (this file)
- `w9-run-detached.sh` — detached runner (pgrep gate, logs to wave dir)
- `w9-probeA-nofix.log`, `w9-probeA-fixed.log` — FAIL-pre / PASS-post
  3-arm repro
- `w9-probeDeath-fixed.log`, `w9-probeDeath-fixed2.log` — death regression
  probe (fixed2 is the clean run)
- `w9-f2-noclass-noclear.log` — subsumption run (W8 clear removed)
- `w9-gate-scratch.sh`, `w9-gate-scratch-chain.log`,
  `w9-gate-scratch-summary.txt`, `w9-gate-scratch-*.log` — scratch gates
- `w9-gate-live.sh`, `w9-gate-live-chain.log`, `w9-gate-live-summary.txt`,
  `w9-gate-live-*.log` — live re-gate
- `w9-save-force-exit.json` — exit-cell save used for the repro
  (seed 91838678)
- `w9-save-backup-pre-wave.json` — pre-wave save, restored at close-out
- `w9-MANIFEST.md`, `w9-ANIMATIONS.md` — staging doc drafts (copied into
  place at merge)

Scratch tree: `~/workspace/goals/game-off-2026-entry/loop-scratch/w9-card-state-hardening-docs-refresh/`
(probe code lives there only; never merged).
