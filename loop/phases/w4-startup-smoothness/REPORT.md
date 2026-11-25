# W4 — Profile and smooth startup / first frames — REPORT

**Wave:** `w4-startup-smoothness` · **Status: DONE, merged to live tree, re-gated green**
**Date:** 2026-11-13 (work 05:08–06:40 PST; deadline 08:05 PST)
**Scope:** startup staging only. No world-gen change, no map-algorithm change, no
gameplay-balance change, no Effekseer orb-scale change. No push, publish, upload,
APK, or link at any point.

## What changed (one file: `scripts/main.gd`, 221,212 → 229,119 B)

`map_gen.gd` untouched (verified identical). All changes are in the bulk
render path of `_rebuild_world` plus a `--profile`-gated harness that stays
in the merged code (dormant without the flag, same precedent as W3's
`--dump-map` / `--climb-probe`):

1. **Merged `_render_layers_and_edges()`** — replaces `_render_layers` +
   `_render_edges` (both deleted). One 200×90 sweep instead of two: the
   neighbour air/solid mask and material groups are computed once per cell
   and shared by the fill, wall and edge decisions. The old code re-derived
   them in `_fill_special`, `_variant` and `_edge_for_cell`, called
   `_fill_special` twice per solid cell, and walked the grid twice with a
   `Vector2i` alloc + `_stream_chunk_of` call per cell. Chunk layers are
   indexed arithmetically (`ci = (y / STREAM) * STREAM_COLS + x / STREAM`;
   in-bounds cells never need the clamp in `_stream_chunk_of`). The merged
   code was verified line-by-line against `_fill_special` /
   `_set_fill_cell` / `_variant` / `_neighbour_mask` / `_edge_for_cell`
   before applying: same transition order (N,E,S,W then corners TL/TR/BL/BR),
   same formulas (`15 + (i if g==0 else 4+i)`, corners `15 + 8 + …`), same
   variant `(mask*3 + (x/4 + y/4)) % nvar`, same OOB-as-solid / OOB-not-air
   edge semantics, platform (t==7) treated as non-solid and as air for
   edges, ore (group 2) exempt from edge transitions.
2. **`_render_props` ore scan folded in** — the merged pass collects ore
   cells (`t == 4 or 5`) in the same y-then-x scan order, so `_render_props`
   uses `_bulk_ore_cells` instead of its own 18,000-cell sweep. Timber
   post / trestle textures hoisted to one load each per rebuild.
3. **`_render_chamber`** — timber-post and torch textures hoisted to one
   load each (the runtime torch in `_place_torch_at` deliberately left
   alone).
4. **`_render_background`** — `cave-silhouettes.png` loaded once, shared by
   the static backdrop + the two parallax sprites.
5. **`_build_tileset`** — `convert(RGBA8)` skipped when the image is already
   RGBA8 (3 sites: main atlas, edge atlas, damage tile).
6. **Harness kept in merged code:** `--profile` prints cumulative
   `W4_STAGE <name> ms=<n>` marks from `_ready` entry (dormant otherwise);
   `--dump-layers` prints every non-empty fg/wall/edge cell so a render
   optimisation can be diffed seed by seed.

## Recovery note (interruption)

The builder was interrupted by a runtime restart mid-verify after the
optimisation was supposedly applied. On resume the recovery note claimed
`w4-apply-opt.py` was "ALREADY APPLIED" — **verified false by diff**:
the scratch `main.gd` still had `func _render_layers` / `func _render_edges`
and no `_render_layers_and_edges`. The script's two earlier attempts had
failed at asserts before its end-of-script write, so nothing had landed;
the 05:21 mtime was the profiling harness, not the optimisation. The script
was fixed (4 assert/anchor bugs, all substring collisions) and applied
cleanly on the third attempt:

- `post.texture = load(timber_post.png)` count also matched `gpost.texture`
  → count with the exact 2-tab prefix.
- `stick.texture = load(torch.png)` count also matched the runtime torch in
  `_place_torch_at` (1 tab) → count with the exact 2-tab prefix; final
  torch-load assert corrected 1 → 2 (chamber hoist local + runtime torch).
- `im.convert(...)` count also matched `dim.convert(...)` → count with a
  tab prefix; both atlas loops guarded (main atlas 3-tab, edge atlas 2-tab).

The applied change was then re-verified structurally (merged function
present, old functions gone, no stale calls, hoists in place, runtime torch
untouched) before any gate ran.

## Profile: before → after (ms, 3 runs each, seed 20261101, xvfb 2400×1080)

Stage deltas from `--profile` runs. Before = `w4-profile1/2/3.log`,
after = `w4-after-profile1/2/3.log`.

| Stage | Before | After | Note |
|---|---|---|---|
| total load_ms (profile runs) | 1472–1624 | 993–1064 | |
| ready_frames (2 initial awaits) | 124–140 | 118–154 | unchanged, by design |
| rebuild_generate | 42–55 | 33 | map gen untouched — treat as noise/cache warmth, not a gain |
| rebuild_tileset | 78–119 | 54–73 | convert-guard; small, low end overlaps noise |
| **rebuild layers+edges** | **448–522** | **64–82** | **~6.5× faster; saves ~380–450 ms** |
| rebuild props+chamber | 366–396 | 227–237 | saves ~140–160 ms (ore-scan fold-in) |
| rebuild_stream | 65–66 | 52–59 | |
| rebuild_await3 (final staged await) | 334 (single split-run sample) | 196–239 | first rendered frame under llvmpipe; not a CPU stage |
| ready_background | 68–72 | 63–91 | unchanged |

**Awaits vs CPU (the W4 lesson, restated):** the 5 startup awaits
(2 in `_ready` + 3 staged in `_rebuild_world`) cost ~650–800 ms of
sandbox load_ms at llvmpipe frame times (~65–135 ms/frame, noisy) but
~83 ms total on a 60 fps phone. They stay: the loading screen must paint.
The optimisation removed CPU work only — layers+edges and props — not
awaits.

## load_ms before / after (plain launches, seed 20261101, save deleted)

| | Run 1 | Run 2 | Run 3 | Range |
|---|---|---|---|---|
| Baseline (pre-opt, scratch) | 2160 | 2231 | 1737 | **1737–2231** |
| After (scratch) | 1011 | 1196 | 1209 | **1011–1209** |
| After (live, post-merge) | 1513 | 1274 | 1009 | **1009–1513** |

Ranges do not overlap the baseline range. Sandbox numbers are noisy and
are **not** phone numbers — the first live run (1513) is the cold-cache
run right after the file copy; the live range still sits clear of baseline.
Honest claim: startup CPU work is down roughly a third to a half in the
sandbox; the phone verdict on feel stays Skit's.

## World identity — PROVEN byte-identical

`--dump-layers` on 3 seeds, sorted `DUMP <type> <chunk> <x> <y> <atlas_x>
<atlas_y>` lines diffed against the pre-optimisation dumps:

| Seed | Cells | Diff vs before |
|---|---|---|
| 20261101 | 21,474 | IDENTICAL |
| 20261102 | 21,902 | IDENTICAL |
| 20261104 | 21,354 | IDENTICAL |

READY lines (load_ms aside) byte-identical on all 3 seeds, e.g. seed
20261101: `rooms=40/40 ore_veins=138 spawn=(10, 44) exit=(190, 42)
connected=true`. Seeds 20261102/20261104: 40/40, ore 93 / 91,
connected=true — same as before. **The generated world did not change.**

## Gates

All runs solo, sequential, `xvfb-run -a -s "-screen 0 2560x1440x24"`,
`--resolution 2400x1080`, seed 20261101. Gate criterion: rc=0 AND
0 SCRIPT ERRORs AND 0 `PASS=false` in the logs.

### Scratch post-opt chain (`w4-gate-after.sh`, 14:19–14:25 UTC, FAIL=0)

- `--selftest` rc=0, errors=0, passfalse=0 (Ph 7/8/9/9B/10 PASS=true)
- `--selftest-p11` tech rc=0 — sword 50→35 pushed 15.8, pot true loot 1,
  slam 20→10, P14 scale 1.50 / rose 110.7
- `--selftest-p11 --class=red` rc=0 — sword 50→30, pot true, slam 20→10
- `--selftest-p11 --class=mage` rc=0 — sword 50→38 (orb damage, W1 fix
  holding), pot true loot 1, dash 146.0, P14 1.50/110.7
- `--selftest-load` rc=0 — see sequencing note below
- load_ms after 1011/1196/1209; profiles 1050/1064/993

### Live re-gate after merge (`w4-gate-live.sh`, 14:27–14:32 UTC, FAIL=0)

Live `scripts/main.gd` verified byte-identical to scratch before gating
(`diff` clean, 229,119 B). All 5 gates rc=0, errors=0, passfalse=0:

- `--selftest` rc=0 (Ph 7/8/9/9B/10 PASS=true)
- `--selftest-p11` tech rc=0 — sword 50→35, pot true, slam 20→10,
  P14 1.50/110.7
- `--selftest-p11 --class=red` rc=0 — sword 50→30, pot true, slam 20→10
- `--selftest-p11 --class=mage` rc=0 — sword 50→38, pot true, P14 1.50/110.7
- `--selftest-load` rc=0 — see sequencing note below
- load_ms live 1513/1274/1009

## Selftest-load sequencing flaw — found and corrected in-wave

The gate scripts (baseline, scratch-after, live) all did `rm -f $SAVE`
before **every** gate, including `--selftest-load`. That test's own doc
says: "Run after a --selftest run (which saves)". With the save deleted
it prints `DEEPFALL_SELFTEST_LOAD FAIL no save file found` and quits —
in **all three** chains identically, including the pre-opt baseline. It is
a harness-sequencing flaw, not a game regression (W4 touches nothing in
save/load), but it meant the load gate as scripted was vacuous: rc=0 and
0 `PASS=false` hid a FAIL line, the same class of miss W3's incident
taught us to watch for.

**Corrected on the live tree:** ran `--selftest` (rc=0, save written),
then `--selftest-load` with the save intact
(`w4-live-selftest-load-proper.log`):
`mined=1 torches=0 slain=0 pos_ok=true hp_ok=true ore_ok=true PASS=true`,
Phase 7 `PASS7=true`, Phase 8 `save_class=mage live_class=mage
class_ok=true`, 0 SCRIPT ERRORs. (The save's class is mage because the
immediately preceding runs were the p11-mage gate; save and live agree,
which is what the test checks.) **Lesson for later waves: do not `rm`
the save before `--selftest-load`; the proper sequence is selftest-then-load.**

## Merge

Explicit file copy only: `loop-scratch/w4-startup-smoothness/scripts/main.gd`
→ `deepfall-game/scripts/main.gd`. No `rsync --delete`, no other files.
Live verified byte-identical to scratch after the copy; `map_gen.gd`
identical (never touched).

## Files

Phase dir `loop/phases/w4-startup-smoothness/`:
`REPORT.md` (this file), `w4-apply-opt.py` (fixed + applied),
`w4-apply-profile.py`, `w4-baseline.sh`, `w4-baseline-summary.txt`,
`w4-baseline-*.log`, `w4-profile*.log`, `w4-profile-split(2).log`,
`w4-dump-before-<seed>.log/.sorted`, `w4-dump-after-<seed>.log/.sorted`,
`w4-gate-after.sh`, `w4-after-summary.txt`, `w4-after-*.log`,
`w4-gate-live.sh`, `w4-live-summary.txt`, `w4-live-*.log`,
`w4-live-selftest-load-proper.log`, `w4-live-selftest-load-setup.log`,
`main.gd.pre-opt.bak`.

## Open items / notes for later waves

- Phone-feel verdict on startup smoothness stays Skit's (sandbox numbers
  only prove the CPU work shrank, not how it feels on the S25).
- `rebuild_generate` reading 33 ms on all three after-runs vs 42–55 before
  is unexplained noise (map gen untouched); do not cite it as a gain.
- The `--selftest-load` gate scripts in the loop's standard terms should
  run the selftest-then-load sequence instead of deleting the save first
  (W7's final verify should use the proper sequence).
- No Godot process left running. No push/publish/upload/APK/link.
