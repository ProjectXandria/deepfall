# W8 — `--selftest-p11` no-class stall diagnosis

**Wave:** `w8-selftest-p11-stall-diagnosis` · **Date:** 2026-11-14 · **Status: DONE**
**Scope:** DEEPFALL only, refine-only, local only. No new features, no push, no APK, no upload.

## Verdict in one paragraph

The reported stall **does not reproduce**: 8/8 varied no-class `--selftest-p11` runs pass on the
current tree (EXIT 0, 0 SCRIPT ERRORs, full P11/P12/P13/P14 green), including exact
reconstructions of every stall report's launch state. No code path in the suite can hang
forever on the current tree — the three awaits between READY and the first P13 print were
each proven to fire, including `physics_frame` while the tree is paused. The most likely
cause of the three stalled runs that night is transient sandbox contention (corroborated:
the kaykit A/B arm's `load_ms=5905`, ~3x this wave's runs, and a documented concurrent
Godot run that same night), not a game or harness bug. **But the investigation did find
and fix a REAL harness bug** (see §3): stale run-card state from a save that arms the
card during `_ready` silently corrupts the whole P11 section while the process still
exits 0. FAIL-pre / PASS-post proven with the identical no-class command. One-line fix,
merged to live, full gates green.

## 1. What the stall was

Three runs on 2026-11-13/14 stalled after `DEEPFALL_PHASE1_READY`, never printing a P13
or P11 line, 0 SCRIPT ERRORs, game booting/loading/spawning fine:

| Arm | Log | Seed | Save at launch | Timeout |
|---|---|---|---|---|
| kaykit A/B | `loop/selftest-p11-kaykit-2026-11-14.log` (04:15) | 91838678 | hp 68, pos (31,82), 40 mined, inv stone 46/coal 4/gold 2 | 300 s, EXIT 124 |
| kaykit solo | `loop/selftest-p11-kaykit-solo-2026-11-14.log` (04:18) | 20261101 | hp 80, class mage, pos (24,32), inv empty | (stall) |
| noskeleton A/B | `loop/selftest-p11-ab-noskeleton-2026-11-14.log` (05:04) | 91838678 | hp 100, pos (16,70), mined 0, inv empty | 300 s, EXIT 124 |
| (earlier) | solo xvfb run | 20261101 | — | 45 min |

Per-class runs (`--class=tech/red/mage`) completed fine throughout, so each class was
verified; only the single-command no-class form was unverified. The A/B arms had already
proven the stall is NOT the KayKit additions (identical stall with skeleton-warrior
removed, `main.gd` restored byte-identical after).

## 2. What the code actually does (no-class path)

Read in `scripts/main.gd` (5,650 lines, live tree):

- `_run_selftest_p11` (line 4631) does **NOT** loop over classes. With no `--class` it runs
  the identical single-class suite as `--class=tech` (default `p11_class := "tech"`,
  lines ~4645-4650). The only code-path difference vs `--class=tech` is one extra
  `player.set_class("tech")` call in `_ready` before the suite. The no-class form is
  therefore not a distinct code path — a hang specific to it would have to come from
  launch state, not from the argument.
- Between READY and the first P13 print the awaits are exactly three:
  1. `await _rebuild_world(false)` — synchronous when `staged=false` (all three
     `process_frame` awaits in `_rebuild_world` are inside `if staged:`).
  2. `await _t11_wait(0.4)` in `_run_selftest_p13_pre` — `SceneTreeTimer`,
     `process_always=true` default, fires even while paused.
  3. `await get_tree().physics_frame` in `_run_selftest_p13_pre` — the only await that
     could hang forever, and only if the physics loop never ticks.
- Pause sources: `show_run_card` (line 5418, sets `get_tree().paused = true`) via the
  `_card_pending` countdown in `_process` (lines ~2425-2428), armed by `player_died()`
  (0.9 s, line 1297) or exit-reached (0.4 s). `_rebuild_world` does NOT reset
  `_card_pending`, `_card_reason`, `_card_open`, or `player.dead`, and its no-save branch
  sets `player.position` + `player.hp` directly instead of calling `respawn_at()` (which
  is what clears `dead`). `_cards_enabled` stays true during p11 (only `--selftest` /
  `--selftest-load` / screenshot modes set it false).

## 3. The REAL bug found and fixed (harness, not the stall)

**Stale run-card state corrupts the suite silently — proven FAIL-pre / PASS-post.**

A save whose player arms the run card during `_ready` (standing on the exit cell, or
dying in the staged-rebuild window) leaves `_card_pending` / `_card_reason` set. The
suite's rebuild does not clear them, so:

1. the stale card opens mid-suite and pauses the tree;
2. the deliberate death in `_run_selftest_p13_pre` re-arms a second card
   (`player_died()` overwrites `_card_pending`/`_card_reason` unconditionally, line
   1297) that opens during the P11 section;
3. every physics-dependent check then reads 0 — while the process still exits 0,
   because **the p11 suite prints no PASS verdict at all** (only `--selftest` phases
   print `PASS=`; `grep PASS=false` in `main.gd` finds nothing in the p11 path).

**FAIL-pre — run F2** (`w8-runF2-noclass-exitforce.log`, seed 91838678, crafted save with
the player on the exit cell (12064, 4512), no-class): `card_pending=0.27` at suite entry,
extract card opened mid-suite, 12 failed expectations, EXIT=0, 0 SCRIPT ERRORs:

- `P13 loot_collected inv_delta=0 corpse_gone=false` (expect 1, true)
- `P11 move touch_move=0.00 dx=0.0`, `multitouch_jump rose=0.0`, `knockback dx=0.0`,
  `aim_mine_down before=3 after=3`, `sword tool=pickaxe golem_hp 50->50 pushed=0.0`,
  `crate_push dx=0.0`, `pot_broken=false loot_delta=0`, `dash dx=0.0 cooldown=0.00`,
  `slam ghoul_hp 20->20`
- `P12 menu panel=false` (expect true), `P14 real_touch_jump touch_jump=false rose=0.0`

The `tool=pickaxe` line is diagnostic: the sword test switches tools by tapping the
hotbar slot (`tu._slot_sword`); while paused the tap does nothing, so the pickaxe never
melee'd the golem. Every zero traces to the paused tree.

**The fix** — `scripts/main.gd`, `_run_selftest_p11`, before `DirAccess.remove_absolute
(SAVE_PATH)` (live lines 4641-4657; identical block on scratch). Test-scoped: the stale
state is legitimate game state (a save on the exit cell SHOULD open the card on load),
so the suite, not the game, is where it is cleared:

```gdscript
if _card_open:
    _close_run_card()
_respawn_timer = 0.0
_card_pending = 0.0
_card_reason = ""
player.dead = false
```

**PASS-post — run F2fix** (`w8-runF2fix-noclass-exitforce-fixed.log`, identical launch
state and command as F2): `p11_entry` probe shows `card_pending=0.00` (was 0.27), and all
12 checks read the W7 anchor values — loot 1/true, move 1.00/96.2, jump rose 110.7,
knockback 124.0, mine 3→0, sword tool=sword 50→35 pushed 15.8, crate 50.1, pot true
loot 1, dash 146.0, slam 20→10, menu panel=true, P14 touch_jump=true rose 110.7,
scale 1.50. EXIT=0, 0 SCRIPT ERRORs.

**Gate gap recorded:** the W6 gate scripts fail a step only on rc≠0, SCRIPT ERROR, or
`PASS=false` — none of which fires on a corrupted p11 run (F2 passed all three). The
W8 live gate script (`w8-gate-live.sh`) adds per-class p11 value checks
(`pot_broken=true`, class sword value, `dash dx=146.0`, `slam ghoul_hp 20->10`,
`touch_jump=true rose=110.7`, `P14 done`). Future p11 gates should keep value checks,
not just rc.

## 4. The stall itself: 8/8 no-class runs pass

All solo, sequential, `xvfb-run -a -s "-screen 0 2560x1440x24"`, `--resolution 2400x1080`,
scratch copy unless noted, with `DEEPFALL_W8` probes in scratch `main.gd` only
(helper + 7 call sites; scratch/live diff = probes + the §3 fix):

| Run | Launch state | Result |
|---|---|---|
| A `runA-noclass-save` | 20261101 + W7 tech soak save (hp 100, pos 24,32) | PASS, EXIT 0, full suite green |
| B `runB-class-tech-save` | `--class=tech` control, same save | PASS, probe trace identical to A — the `--class` arg makes no difference |
| C `runC-noclass-91838678-nosave` | 91838678, save deleted | PASS, READY 40/40 connected=true |
| D1 `runD1-noclass-91838678-deepsave` | 91838678 + crafted deep save (hp 68, row 82, 40 mined) | PASS; player fell 22 px as the mined floor gave way, hp stayed 68 |
| D2 `runD2-noclass-91838678-prefixed-deepsave` | 91838678 + deep save + PRE-FIX 39/40 map (W6 repair-leg revert on scratch only) | PASS, READY `39/40 connected=false` exactly as in the A/B logs |
| E `runE-noclass-20261101-magesave` | 20261101 + crafted mage save (hp 80, class mage — the solo arm's exact launch state) | PASS, EXIT 0, P14 done |
| F1 `runF1-noclass-deathforce` | 91838678 + deep save at hp 1 (force a death during `_ready`) | PASS — the player survived the window (ready probe hp=1, dead=false); no enemy landed a hit |
| F2 `runF2-noclass-exitforce` | 91838678 + save on the exit cell (force the card during `_ready`) | COMPLETED, EXIT 0 — but 12 checks failed (the §3 bug). Proves the pause path corrupts, not hangs |
| F2fix | identical to F2 + the §3 fix | PASS, all 12 checks green (see §3) |

Eliminated as triggers: the `--class` argument, seed 91838678, a deep/low-hp save, the
pre-fix 39/40 unconnected map, a saved mage class, a death during `_ready`, and a run
card opening mid-suite. Two further facts from the probes:

- **`physics_frame` fires while paused** (F2: `p13_pre_physics_frame` and
  `p13_post_physics_frame` both printed with `paused=true card_open=true`). The one
  await that could have hung on a pause does not. There is no pause-based deadlock in
  the pre-P13 path.
- **The stall logs cannot prove "no P13 line ever printed."** All three are ~2.4 KB,
  under the ~4 KB block-buffer threshold (see AGENTS.md: a redirected Godot log is
  block-buffered; a frozen tail proves nothing). What they prove is only that the runs
  did not finish within their timeouts. The 45-minute run is the strongest stall
  evidence, but it ran without probes and its log was not preserved with CPU data.

Remaining explanation for the original stall: a transient sandbox-environment condition
that night. Supporting evidence: the kaykit A/B arm's `load_ms=5905` vs 1663-3652 ms
across this wave's runs (~3x slower, i.e. the host was heavily loaded); W6 documents
another agent's Godot run overlapping a soak that same night; background exec runs live
in separate containers with separate `/tmp`, and `pgrep` cannot see other containers'
Godot processes, so a run believed solo may not have been. At ~0.1 fps under such
contention the suite's ~40 timer waits + ~10 `frame_post_draw` screenshots need ~500 s
of wall time — consistent with the 300 s A/B timeouts. A deliberate contention test was
NOT run: it would break the loop's solo-run rule and could only prove slowness, not the
stall's cause. No deliberate reproduction of the 45-minute stall exists.

## 5. Live gates (after merging the §3 fix)

Script: `w8-gate-live.sh` (modeled on W6's, plus p11 value checks). All solo, sequential,
seed 20261101, live tree, Godot 4.8 beta 1. Full log in `w8-gate-live-summary.txt`,
per-step logs `w8-gate-live-*.log`. Chain finished 2026-11-14T08:48:45Z.

| Step | rc | SCRIPT ERRORs | PASS=false | p11 values | READY |
|---|---|---|---|---|---|
| selftest | 0 | 0 | 0 | — | `seed=20261101 rooms=40/40 ore_veins=138 spawn=(10, 44) exit=(190, 42) connected=true` load_ms=2786 |
| selftest-load | 0 | 0 | 0 | — | same anchor, load_ms=2097 |
| p11-tech | 0 | 0 | 0 | OK (sword 50→35) | same anchor, load_ms=1756 |
| p11-red | 0 | 0 | 0 | OK (sword 50→30) | same anchor, load_ms=1663 |
| p11-mage | 0 | 0 | 0 | OK (sword 50→38) | same anchor, load_ms=2310 |
| p11-noclass | 0 | 0 | 0 | OK (sword 50→35) | same anchor, load_ms=1681 |

Anchors hold: seed 20261101 READY line exact; SAVE_VERSION 9; P14 scale 1.50 / rose
110.7; ENEMY_SPAWNS total=26. The no-class form now passes on the live tree too.

## 6. What changed (files + lines)

- `deepfall-game/scripts/main.gd` — **the only live-tree change**: 16 added lines in
  `_run_selftest_p11` (live lines 4641-4657), the stale-card clear from §3. Verified by
  diff: live vs scratch `main.gd` differs only by the W8 probe insertions; no other
  live-tree file differs from the scratch copy except regenerated
  `screenshot_p11_*.png` suite artifacts.
- `deepfall-game/scripts/map_gen.gd` — **unchanged in live**. The W6-fix revert used for
  run D2 existed only on scratch and was restored from live before run E; live keeps
  the W6 repair-leg fix.
- Scratch only (never merged): `DEEPFALL_W8` probe helper + 7 call sites in scratch
  `main.gd`; crafted saves `w8-save-crafted-91838678-deep.json`,
  `w8-save-crafted-20261101-mage.json`, `w8-save-force-death.json`,
  `w8-save-force-exit.json`; pre-W8 save backup `w8-save-backup-20261101.json`.
- The pre-W8 save was restored at close-out (seed 20261101, hp 100, pos (1585.99,
  2071.99), class tech — the W7 soak save), so the on-disk save state is as W8 found it.

## 7. What the gates could NOT prove

- The original stall's root cause: no reproduction exists, so the environmental
  explanation is the best-supported inference, not a proof. If a no-class stall ever
  recurs, re-run with the `DEEPFALL_W8` probes (they are preserved in the scratch
  copy) and capture `ps` CPU time — the probes show the exact await and the
  paused/card state, which the 2026-11-13 logs lacked.
- Real-phone behavior: all runs are sandbox/xvfb at ~5 fps under llvmpipe. P14 phone
  geometry (scale 1.50) is the xvfb proof, not a phone proof.
- The §3 fix's effect on real play is nil by construction (it runs only at suite
  entry, before the fresh-world rebuild); real play never reaches it.
- Per-class verification stands either way: tech/red/mage all pass on live, and the
  no-class form now passes too.

## 8. Left for Skit / follow-ups

- **Nothing needs his word from this wave**: no push, no APK, no upload. The fix is
  test-code only and already merged to the live tree; GitHub is still at `103f450a`
  (push remains his call, as do the Game Off entry pick and the Effekseer orb scale).
- **Follow-up (not done here):** `_rebuild_world` still does not reset `_card_pending` /
  `player.dead` in general — the §3 fix covers the suite only. If a future wave wants
  the rebuild itself to be card-clean, it needs its own FAIL-pre proof; F1/F2 show
  neither the death nor the card path hangs the suite, so this is hardening, not a bug
  fix.
- **Gate hygiene:** keep p11 value checks in future gate scripts — rc + SCRIPT ERROR +
  `PASS=false` cannot see a corrupted p11 run (F2 proved it).
- His phone verdicts are still outstanding (v1.2 install/art; skeleton-warrior
  sighting; deep-cave density; climb-out comfort; startup feel). The v1.2 download link
  expires Sun Nov 15, 2026 ~23:13 PST.

## Logs and artifacts (all in this wave dir)

`loop/phases/w8-selftest-p11-stall-diagnosis/`

- `REPORT.md` (this file), `w8-run-detached.sh` (detached runner with pgrep gate)
- Runs: `w8-runA-noclass-save.log`, `w8-runB-class-tech-save.log`,
  `w8-runC-noclass-91838678-nosave.log`, `w8-runD1-noclass-91838678-deepsave.log`,
  `w8-runD2a-dumpmap-prefixed.log`, `w8-runD2-noclass-91838678-prefixed-deepsave.log`,
  `w8-runE-noclass-20261101-magesave.log`, `w8-runF1-noclass-deathforce.log`,
  `w8-runF2-noclass-exitforce.log`, `w8-runF2fix-noclass-exitforce-fixed.log`
  (each with a `.done` marker)
- Crafted saves: `w8-save-crafted-91838678-deep.json`,
  `w8-save-crafted-20261101-mage.json`, `w8-save-force-death.json`,
  `w8-save-force-exit.json`, `w8-save-backup-20261101.json`
- Live gates: `w8-gate-live.sh`, `w8-gate-live-summary.txt`, `w8-gate-live-*.log`
- Scratch tree (probes + fix): `loop-scratch/w8-selftest-p11-stall-diagnosis/`
