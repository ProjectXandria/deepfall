# W3 — Guarantee a climb-out path from deep rooms — REPORT

**Slug:** `w3-climb-out-comfort` · **Status: DONE** · **Finished 2026-11-13 ~04:39 PST (12:39 UTC)**
**Builder:** subagent session `12ab8930-74be-47c0-8089-24b9825e4250`, spawned from the main chat.
**Scope:** DEEPFALL only, refine-only. No push, publish, upload, APK link, or GitHub push. Effekseer orb scale untouched.

## Verdict

**DONE, gates green on scratch AND live.** From any room below row 60 the player can now
climb back up without mining: every vertical corridor leg carries stepped one-way platforms,
one row apart. Proven two ways — a deterministic scripted probe climbs 10 rows on 3 seeds,
and the soak bot climbs 27 rows (scratch) / 36 rows (live) in 180 s, where the pre-W3 bot
climbed 0 rows and camped the pit.

**One regression was found and fixed inside this wave** (see §5): the ledges collided with the
spawn chamber's static lights and the Phase 7 lantern test's fixed placement spot, failing
Phase 7 and Phase 10 in the first merge. Both are fixed, and the gate scripts now check the
per-phase PASS lines, not just rc=0 — rc=0 alone hid the failures.

## 1. What changed (live tree)

Only two files differ from the W2 tree, verified by `diff -rq`:

### `scripts/map_gen.gd` — the wave's game change
- The `corridor` lambda now records every vertical leg as `[bx, min(ay,by), max(ay,by)]`
  in a `vlegs` array (3-wide shaft at `bx..bx+2`).
- After validation (after `reached` is computed, before the variety/wall step), a ledge pass
  adds stepped one-way PLATFORMs (tile 7, the existing one-way platform tile) in every leg:
  rows `top+3..bot+2`, one row apart (64 px rise per hop — a single jump rises ~117 px /
  ~1.8 tiles from JUMP_VEL -640 / GRAVITY 1800 with APEX_MULT 0.55, so 1-row steps are
  required; a human can double-jump past every other step), alternating 2-wide left/right
  (`bx,bx+1` on even rows, `bx+1,bx+2` on odd) so a 1-wide gap always stays open for
  falling back down.
- Fully deterministic geometry — **NO rng calls**, so the RNG stream for ore/coal/wood is
  untouched. Ledges only replace AIR (never solid or ore); flood-fill treats PLATFORM as
  traversable, so `connected` cannot change.
- Return dict now also includes `"legs": vlegs` (additive; the save is untouched).
- Prints `DEEPFALL_W3_LEDGES legs=%d cells=%d`.

Why ledges belong in shafts, not just rooms: a corridor leaves a room floor at most 1 row
above it (the horizontal leg runs at room-centre height), so room→corridor is already
jumpable. The unclimbable part is the vertical leg itself — a 3-wide shaft up to ~30 rows
with no wall-jump. That is what the ledges fix.

### `scripts/main.gd` — one game-code robustness fix + test-only harness
- **Game code:** `_render_chamber` — the two static warm chamber lights no longer silently
  skip when their cell is occupied; they scan rows `floor_y-2, -3, -1, -4` for a free cell
  (§5 explains why this was required). The light still hangs in the chamber, just a row
  up or down. Fallback is the old skip if no cell is free.
- **Test-only:** Phase 7 lantern placement now scans a few steps around spawn instead of one
  fixed spot (§5); `_run_soak` climb metric (`deep_row` / `climb_rows`, `SOAK_CLIMB*`
  prints) + climb-mode bot (fixes 1–3, §4); new `--climb-probe` mode (`_run_climb_probe`,
  deterministic scripted climb, no mining); new `--dump-map` mode (prints rooms/legs/spawn/
  exit for offline analysis).

## 2. Gates

All runs solo, sequential, `xvfb-run -a -s "-screen 0 2560x1440x24" --resolution 2400x1080`,
seed 20261101 unless noted. **Every step rc=0, 0 SCRIPT ERRORs, 0 `PASS=false`** (the
`passfalse` column is new in this wave — see §5).

### Scratch gate chain 8 (final, with fixes) — done 2026-11-13 12:16:36 UTC
| step | result |
|---|---|
| `--selftest` | rc=0, 0 errors, passfalse=0 — Ph 6 a/a3/c/b all true, Ph 7/8/9/9B/10 PASS=true |
| `--selftest-p11 --class=tech` | rc=0, sword 50→35 pushed 15.8, pot true loot 1, P14 scale 1.50 / rose 110.7 |
| `--selftest-p11 --class=red` | rc=0, sword 50→30 pushed 15.8, pot true loot 1, P14 1.50 / 110.7 |
| `--selftest-p11 --class=mage` | rc=0, sword 50→38 pushed 11.7, pot true loot 1, P14 1.50 / 110.7 |
| `--selftest-load` | rc=0, PASS=true (pos/hp/ore all ok) |
| `--climb-probe` | rc=0, `CLIMB_PROBE_PASS start=69 best=59 climbed=10 t=10` (leg x=110 top=40 bot=69) |
| seed sweep `--selftest` 20261102 | rc=0, `rooms=40/40 ore_veins=93 spawn=(10,16) exit=(189,41) connected=true`, LEDGES 47/1302 |
| seed sweep `--selftest` 20261104 | rc=0, `rooms=40/40 ore_veins=91 spawn=(12,19) exit=(183,80) connected=true`, LEDGES 47/1139 |
| `--soak --soak-secs=180` tech | rc=0, `deaths=0 stuck=5 kills=0 mined=0 rooms=3 climb=27 deep=56 fps_min=1 fps_avg=5 foes0=70 foes0max=50` |

### Live re-gate, chain 9 (merged tree) — done 2026-11-13 12:39:06 UTC
| step | result |
|---|---|
| `--selftest` | rc=0, 0 errors, passfalse=0 — all phases PASS=true |
| `--selftest-p11` tech / red / mage | rc=0 each — tech 50→35, red 50→30, mage 50→38, all pot true, P14 1.50 / 110.7 |
| `--selftest-load` | rc=0, PASS=true |
| `--climb-probe` | rc=0, `CLIMB_PROBE_PASS start=69 best=59 climbed=10 t=10` |
| `--soak --soak-secs=180` tech | rc=0, `deaths=0 stuck=7 kills=0 mined=8 rooms=4 climb=36 deep=54 fps_min=1 fps_avg=3 foes0=47 foes0max=14` |

### READY-line invariant — HELD, byte-identical on every run
`DEEPFALL_PHASE1_READY seed=20261101 rooms=40/40 ore_veins=138 spawn=(10, 44) exit=(190, 42) connected=true`
(load_ms varies run to run — 6493 / 3105 / 2975 across chains — host contention noise, informational only.
LEDGES on this seed: `legs=46 cells=944` on every run.)

### Climb probe generalises across seeds (direct runs, fixed probe)
- seed 20261101: `PASS start=69 best=59 climbed=10 t=10` (leg x=110 top=40 bot=69 len=29)
- seed 20261102: `PASS start=83 best=73 climbed=10 t=10` (leg x=25 top=16 bot=83 len=67)
- seed 20261104: `PASS start=80 best=70 climbed=10 t=9` (leg x=143 top=7 bot=80 len=73)

## 3. Soak progression — the climb gate, measured

| run | stuck | kills | mined | rooms | climb | deep |
|---|---|---|---|---|---|---|
| Beta 2026-11-09 | 10 | 2 | 11 | 1 | — (no metric) | ~83 |
| W1 | 6 | 2 | 6 | 3 | — (no metric) | ~81 |
| W3 chain 2 (fix-1 bot) | 11 | 0 | 28 | 3 | 3 | 73 |
| W3 chain 6 (fix-3 bot) | 6 | 0 | 1 | 2 | **14** | 56 |
| W3 chain 8 scratch (fixed tree) | 5 | 0 | 0 | 3 | **27** | 56 |
| W3 chain 9 live (fixed tree) | 7 | 0 | 8 | 4 | **36** | 54 |

The brief's gate was "a soak showing the bot climbing at least 10 rows out of the deep cave":
**met on scratch (27) and on live (36).** The bot climbs the ledges repeatedly (chain 9:
CLIMB_MODE → climb 12 → STALL → climb again to 27, then a second shaft to 36). Kills=0 in
all W3 soaks is the bot camping shafts, not an encounter regression — W2's opt-B foes are
room-local and the bot spends its time climbing, not fighting; foes0 stretches (47–84 s)
are the same shape as W2's baseline. FPS 1–6 is the sandbox software renderer, not phone
numbers.

## 4. How the climb was proven (bot fixes + probe iterations)

The level was climbable from chain 2 (ledges in, READY identical, all suites rc=0) but the
bot could not demonstrate it — the brief's gate is a soak, so the bot had to be fixed.
All bot/probe work is test-only in `main.gd` (`_run_soak` / `_run_climb_probe`).

- **Fix 1 — climb mode on ledges:** when stuck, check whether the player stands on a
  one-way platform (`fg` cell below is tile 7); if so, enter climb mode instead of mining:
  flip direction, press JUMP, 6 s window, no pick. Chain 3 partial soak (killed by the
  11:05 UTC runtime restart at t=100) showed climb mode firing but the bot falling back
  down after the window.
- **Fix 2 — landing-synced hops:** the 6 s window + re-press every 0.5 s made the bot
  ping-pong mid-air with ~zero net horizontal travel. Changed to a persistent `climbing`
  bool; hop ONLY on landing (`player.on_ground`); exit on solid ground (`SOAK_CLIMB_END`).
  Chain 4 exposed the latch: hopping in place moves >12 px vertically per hop, so the stuck
  timer kept resetting and `climbing` never exited — the bot sat at (25,44) from t=20 to
  t=180 with 1 stuck event.
- **Fix 3 — stall exit + gentle stick (ported from the probe):** exit climb mode
  (`SOAK_CLIMB_STALL`) when no row is gained in 5 s of climbing, gated on having climbed
  ≥3 rows; on entry, find the shaft leg from `data["legs"]` and use position-before-climb
  + a GENTLE ±24 px stick inside the shaft. The move stick is analog/proportional
  (RADIUS 72, DEAD 0.18): a full ±80 drag runs 270 px/s (~5.5 tiles per jump, overshoots a
  3-wide shaft); ±24 px is touch_move ~0.25 (~1.4 tiles per jump — the climb step).
  Chain 6: climb=14. Chain 8/9: climb=27/36.
- **Probe iterations (seed 20261101, leg [110,40,69]):** 1 — FALSE PASS (a death with cards
  disabled auto-respawns at spawn after 1.2 s and read as a 36-row "climb"; probe now bails
  `CLIMB_PROBE_FAIL reason=died` on any `_deaths` change). 2 — FAIL climbed=0 (the move
  stick dragged right during settle, drifting out of the shaft; fix: hold centred, wait for
  the actual landing — at ~5 fps a fixed 1.0 s settle is not a landing). 3 — FAIL climbed=2
  (full ±80 drag overshoots the shaft). 4 — FAIL climbed=2 (shaft-centre steering alone
  insufficient). 5 — FAIL climbed=2 (position-before-climb alone insufficient). 6 — **PASS
  climbed=10** (gentle ±24 stick; clean 1-row-per-hop climb, rows 67→59).
- **Stale-marker incident:** chain 5 ran the probe with the buggy (pre-fix) code and its
  false pass created `w3-climb-probe.done`; chain 6 skipped the step on that marker. The
  stale marker + log were deleted and chain 7 re-earned the marker with the fixed probe
  (`PASS start=69 best=59 climbed=10 t=10`). Gate scripts now also treat any `PASS=false`
  as a failure (see §5).

## 5. Regression found by this wave — and fixed (read this first)

**What happened:** chain 2 (10:36 UTC) looked green — selftest, p11 ×3, load, sweeps, soak
all rc=0, 0 SCRIPT ERRORs. But the selftest log actually contained
`DEEPFALL_SELFTEST_PHASE7 done PASS=false` and `DEEPFALL_SELFTEST_PHASE10 done PASS=false`,
and the first merge (11:48 UTC) + live chain went ahead on rc=0 alone. The live gate
showed the same two failures. Caught on the numbers review before any report was written.

**Root cause — one cause, two symptoms.** The ledge pass writes PLATFORM cells into row 44
of the spawn chamber (shaft `[10,16,43]` mouths right by spawn; its lowest ledges land at
x=10–12, rows 43–45):
- Phase 7: the test places a lantern at spawn+1. `_place_lantern` tries 4 candidates around
  the player cell; cell (11,44) is now a platform, and the supports for (12,44) — (12,43)
  and (12,45) — are platforms too (and `_is_solid_cell` correctly excludes tile 7). All
  four fail → `DEEPFALL_LANTERN_NOSPACE`, lantern cell (-1,-1), `lantern_restored=false`.
  W2's run had placed at (11,44).
- Phase 10: the polished chamber's two static warm lights hang at `(rx+2, floor_y-2)` and
  `(rx+rw-3, floor_y-2)` — row 44. The left light's cell is now a platform, and the old
  code silently `continue`d → 1 light → `embers=6 (expect 12)`.

**The game behavior is correct in both cases** — a lantern cannot hang inside a platform,
and a light should not spawn inside one. What was wrong was (a) the light code's silent
skip, which deleted half the spawn chamber's warm light, and (b) the test's assumption that
one fixed spot near spawn is always placeable.

**Fixes (both on scratch, re-gated, then re-merged):**
1. `_render_chamber` (game code): each chamber light scans rows `floor_y-2, -3, -1, -4`
   for a free cell instead of skipping silently. The light still hangs in the chamber.
2. Phase 7 test (test-only): scan player positions `spawn+1.5, +2.5, +0.5, +3.5, -0.5`
   until a lantern places. On seed 20261101 it takes the 5th try — `LANTERN_PLACED
   cell=(9, 44)`, `lantern_restored=true`, Phase 7 PASS=true; Phase 10 embers back to 12.
3. `w3-gate.sh` / `w3-gate-live.sh`: every step now also fails on any `PASS=false` in its
   log (`passfalse` column). A `.done` marker now means rc=0 AND 0 errors AND 0 PASS=false.

**Verification of the fix:** chain 8 (full scratch re-gate) and chain 9 (full live re-gate)
are all green with `passfalse=0` on every step (§2). The pre-fix chain-2/chain-6 and
first-live-chain logs are kept in the phase dir for the record — do not mistake their
`rc=0` lines for passes; their Phase 7/10 lines say PASS=false.

## 6. Mining feel — what the brief asked to say

Ledges sit in corridor shafts, never in solid rock, so **mining itself is untouched** — the
pick never hits a ledge while digging rock, and ore veins / coal / wood are byte-identical
(READY line unchanged, ore_veins=138). Ledges use the existing one-way platform tile (7),
the same tile as the pre-existing room platforms: no new tile, no new mining interaction.
What a human will notice is the climb itself: alternating 2-wide steps with a 1-wide gap
to fall back down, single-jumpable per step, double-jumpable every other step. Whether
that feels good, and whether the ledges read as climbable at a glance, is Skit's phone
verdict — the gates prove the path exists and is traversable, not the feel.

## 7. Known limitations / open items

- **Phase 6 `a3` is a pre-existing flake, not a W3 finding.** `chunk_visible` on the return
  leg flips run to run at sandbox fps: W2-base false, W2-live true, W1-live false,
  chain 8 true, chain 9 live true. The Phase 6 "done" line is informational (it sets no
  `ok`), and the value is timing-dependent chunk streaming, not map geometry.
- **Soak fps (1–6) and load_ms are sandbox llvmpipe numbers**, not phone numbers.
- **The bot still cannot mine its way out of a pit** — it climbs ledges now, but a shaft
  with no ledges (there are none left on this map — every leg has them) would still strand
  it. Not a game bug: a human digs stairs or uses platforms.
- **Human verdicts still open (Skit's):** climb-out comfort, deep-cave encounter feel
  (W2 opt-B), first-ten-minutes feel, startup-lag feel, Effekseer orb scale 1.0 vs 2.0.
- **No APK built in this wave** (loop scope: verify only; W7 rebuilds the APK). No push to
  GitHub — local tree only until Skit says push.

## 8. Files

- Report: `loop/phases/w3-climb-out-comfort/REPORT.md` (this file)
- Gate scripts: `loop/phases/w3-climb-out-comfort/w3-gate.sh` (scratch, hardened),
  `w3-gate-live.sh` (live, hardened)
- Scratch logs: `w3-selftest.log`, `w3-p11-{tech,red,mage}.log`, `w3-selftest-load.log`,
  `w3-climb-probe.log` (+ `w3-climb-probe6.log`, `w3-climb-probe-s20261102.log`,
  `w3-climb-probe-s20261104.log`), `w3-sweep-s2.log`, `w3-sweep-s3.log`, `w3-soak.log`,
  `w3-gate-summary.txt` (chain 8 is the final scratch chain; chains 2/6 logs are the
  pre-fix record — see §5)
- Live logs: `w3-live-*.log`, `w3-gate-live-summary.txt` (chain 9 is the final live chain;
  the first live chain's logs are the pre-fix record — see §5)
- Probe/dump artifacts: `w3-dump-map.log`, `w3-climb-probe2..5.log` (failed iterations),
  `w3-main-pre-fix2-backup.gd`
- Changed in the live tree: `scripts/map_gen.gd`, `scripts/main.gd` (only — `diff -rq`
  live vs scratch `scripts/` is clean)
