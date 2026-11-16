# DEEPFALL Chunk 8 — Terraria techniques as DEEPFALL-originals (report §8.2, steps 1–4)

Worktree: `~/workspace/deepfall-production/worktrees/chunk-8/deepfall-game/`
Live tree untouched. No push, no publish, no APK. Shift I (Amber/Void shift)
explicitly OUT OF SCOPE — not built. Reference seed `20261101` throughout.
Nothing here copies Terraria names, numbers, art, or tables: Deepfall's own
ore names, bands, and thresholds, documented below.

## (a) Depth-banded ore — `scripts/map_gen.gd`

- New pure function `DeepfallMapGen.ore_for_band(y)`:
  `y < 20` → no precious ore (stone stays stone),
  `20 <= y < 50` → gold (4, middle workings),
  `y >= 50` → amber (5, deep workings).
- The ore walk is otherwise untouched: same rooms, corridors, walk geometry.
  The old flat coin flip `rng.randi_range(0, 1)` is kept as a discarded call
  (`_flip`) so the RNG stream — and therefore the coal/wood veins that read
  it after this pass — stays byte-identical. Only ore TYPE per cell changes.
  Veins still grow by neighbour replacement, still never in the spawn room
  or corridors (start above room ceilings in solid cells).
- **Band choice (reason):** the brief's suggested 30/60 split was measured
  first and rejected. The 10-row ore histogram on 6 seeds
  (`merges/chunk8-baseline-hist.log`) shows the reference seed's deep band
  `y >= 60` holds only 5 ore cells total, so amber would be near-extinct in
  the reference world. The 20/50 split keeps gold >= 15 and amber >= 23 on
  every seed while still giving a real no-ore shallows (top ~2 room rows).

### Ore census — distinct cells (ready_ore = placements, veins = 4-connected ore groups)

Baseline (flat coin flip) — `merges/chunk8-baseline-census2.log`:

| seed | ready_ore | veins | gold | amber | coal | wood | gold bands [<20,20–49,50+] | amber bands |
|---|---:|---:|---:|---:|---:|---:|---|---|
| 20261101 | 138 | 53 | 43 | 51 | 47 | 68 | [15,18,10] | [19,19,13] |
| 57109915 | 92 | 40 | 39 | 35 | 47 | 83 | [13,17,9] | [12,7,16] |
| 91838678 | 139 | 58 | 47 | 58 | 45 | 76 | [13,19,15] | [21,21,16] |
| 12345678 | 136 | 54 | 43 | 48 | 44 | 80 | [17,12,14] | [16,14,18] |
| 31415926 | 121 | 55 | 32 | 49 | 34 | 37 | [10,10,12] | [8,18,23] |
| 77700011 | 89 | 50 | 34 | 36 | 40 | 64 | [10,7,17] | [13,8,15] |

After banding — `merges/chunk8-post-ore-census.log` (predictions from the
baseline bands matched exactly on all 6 seeds):

| seed | ready_ore | veins | gold | amber | coal | wood | gold bands | amber bands | rooms |
|---|---:|---:|---:|---:|---:|---:|---|---|---:|
| 20261101 | 87 | 34 | 37 | 23 | 48 | 70 | [0,37,0] | [0,0,23] | 40/40 connected |
| 57109915 | 62 | 25 | 24 | 25 | 49 | 85 | [0,24,0] | [0,0,25] | 40/40 connected |
| 91838678 | 95 | 38 | 40 | 31 | 46 | 78 | [0,40,0] | [0,0,31] | 40/40 connected |
| 12345678 | 87 | 36 | 26 | 32 | 46 | 82 | [0,26,0] | [0,0,32] | 40/40 connected |
| 31415926 | 97 | 42 | 28 | 35 | 34 | 40 | [0,28,0] | [0,0,35] | 40/40 connected |
| 77700011 | 60 | 36 | 15 | 32 | 41 | 66 | [0,15,0] | [0,0,32] | 40/40 connected |

- Gold is middle-band only, amber deep-band only, shallow band has zero
  precious ore on every seed. Total precious ore fell ~35–45% (shallow
  veins are stone now) — see open decision 2.
- Coal/wood moved +1..+3 cells per seed (their walks are identical, but they
  may now land on ex-ore stone cells they previously had to skip). Their
  code was not changed. Topology and connectivity unchanged (40/40, all seeds).

## (b) Overlay TileMapLayer — `scripts/main.gd`

- New per-stream-chunk `_overlay_layers` array (78 layers, z_index 3, above
  damage), parallel to `_damage_layers`, with `_overlay_layer_for()`,
  created in `_create_chunk_layers()`, toggled in `_apply_chunk_visibility()`,
  cleared in `_clear_dynamic()`, bulk-rendered by `_render_overlays()` in
  `_rebuild_world()` after `_render_layers_and_edges()`, and recomputed per
  cell + 8 neighbours on every mine (`_mine_at()` 3×3 loop, alongside
  `_set_fill_cell()` / `_update_edge()`).
- Rule `_overlay_for_cell(c)`: pure function of fg + 8 neighbours,
  deterministic hash, no RNG, no gameplay effect. Only stone-family solids
  (3/9/10/12) ever carry an overlay; ore cells exempt (don't darken the
  pickup), air/platform/slope cells never. Priority path > moss > crack.
  - **path (2):** air above this cell and above both horizontal neighbours
    (a walked floor-top run), hash `(x*7+y*13)%5==0`.
  - **moss (0):** exposed top face (air above), hash `(x*31+y*17)%7==0`.
  - **crack (1):** exposed side face (air E or W), hash `(x*13+y*29)%11==0`.
- Art reused, no new sprites: moss = `assets/tiles2/mossy-stone_v0.png`,
  crack = `assets/tiles2/cracked-stone_v0.png`,
  path = `assets/tiles2/dirt_v0.png` (a worn dirt patch over stone).
  Overlay tileset built in `_build_tileset()` like the damage tileset.
- Selftest census (seed 20261101, live world): overlay total 290 —
  moss 89, crack 59, path 142 — bad placement 0, recompute mismatch 0.
  Mine-recompute check: mined cell's overlay erased, all 8 neighbours
  recompute to the fresh rule. Overlay never touches `fg` (collision is the
  fg grid only), so it cannot affect gameplay.
- Note: the overlay total varies by ±1 between runs because the selftest
  mines cells and the isolated-HOME save persists them across runs; the
  rule agreement (mismatch 0) holds either way.

## (c) 16-tile Terrain Set, Match Sides — `deepfall_terrain.tres`

- `deepfall_terrain.tres` (worktree root): real Godot 4 TileSet resource —
  tile size 64, one Terrain Set, mode Match Sides, terrains rock (0) /
  dirt (1), 32 tiles: `(mask 0..15, row 0 rock / row 1 dirt)`, each tile's
  peering bits encoding its mask (N=1, E=2, S=4, W=8; bit set = that side
  expects the same terrain, clear = empty terrain −1).
- Atlas `assets/atlas3/terrain_atlas.png` (1024×128, 16×2): composited from
  the EXISTING `rock_0..15.png` / `dirt_0..15.png` variants — no new art.
- Builder `scripts/build_chunk8_terrain.gd` (re-runnable, verifies every
  tile's terrain + peering bits on read-back, exits 1 on mismatch):
  `godot --path . --headless --audio-driver Dummy --script res://scripts/build_chunk8_terrain.gd`
  — run AFTER an editor import so the atlas PNG is imported first.
- Runtime painter `_paint_terrain_cells(layer, cells, terrain_id)`:
  `set_cells_terrain_connect(cells, 0, terrain_id, false)`. Godot 4.8 note:
  TileMapLayer has NO `update_terrain_connections()` (that was the pre-split
  TileMap API — calling it is a script error); `set_cells_terrain_connect`
  computes connections immediately, so one call per terrain is the painter.
- Wiring in `_set_fill_cell()` and the bulk `_render_layers_and_edges()`
  (both paths, same rule): rock/dirt plain fills take the 16-tile mask
  `_terrain_mask(c)` as the variant row instead of the Phase 4 hash variant.
  Special transition/corner art still wins; ore/wood/brick keep the hash
  variant. No jump to 47 tiles.
- Validation patterns (`_run_selftest_chunk8`, part c) — all on the real
  `.tres` via the runtime painter: isolated rock → `(0,0)`, isolated dirt →
  `(0,1)`; 1-wide corridor ends `(2,0)`/`(8,0)`, middle `(10,0)`; concave L
  `(6,0)`/`(8,0)`/`(1,0)`; void-on-3-sides pair `(2,0)`/`(8,0)` — PASS.
  Live-world cross-check: 11,802 painted cells, painter mismatch 0;
  11,215 plain-fill cells, fg variant mismatch 0.

## (d) Flood-fill CI — `scripts/main.gd` + `merges/run-chunk8-floodfill.sh`

- `_run_selftest_chunk8_floodfill()`: for each of 6 fixed seeds it rebuilds
  the FULL world (`_rebuild_world(false)` — rooms + props + chests) and
  re-flood-fills independently of `generate()`'s own check (helper
  `_chunk8_floodfill`, air + platform traversable). Requires every room
  centre + exit + every chest prop cell reachable from spawn. It relies on
  `map_gen`'s existing repair-corridor path and never silently regenerates;
  a failing seed is reported by number. Standalone flag
  `--selftest-chunk8-floodfill`; runner `merges/run-chunk8-floodfill.sh`
  writes the per-seed table to `merges/chunk8-floodfill.log` (isolated HOME
  `merges/home-chunk8` so the live save slot is never touched).
- Seeds: 20261101, 57109915, 91838678, 12345678, 31415926, 77700011.

| seed | rooms | exit | chests | gen_connected | PASS |
|---|---:|---|---|---|---|---|
| 20261101 | 40/40 | true | 7/7 | true | true |
| 57109915 | 40/40 | true | 4/4 | true | true |
| 91838678 | 40/40 | true | 5/5 | true | true |
| 12345678 | 40/40 | true | 11/11 | true | true |
| 31415926 | 40/40 | true | 5/5 | true | true |
| 77700011 | 40/40 | true | 4/4 | true | true |

## Verification (solo, sequential, logs under `merges/`, isolated HOME)

| check | log | rc | script errors | result |
|---|---|---:|---:|---|
| editor import (re-run to exit 0) | `merges/chunk8-import-2.log` | 0 | 0 | clean |
| terrain `.tres` build | `merges/chunk8-terrain-build.log` | 0 | 0 | `CHUNK8_TERRAIN_BUILD OK tiles=32 terrains=rock,dirt mode=Match_Sides` |
| flood-fill CI (runner) | `merges/chunk8-floodfill.log` | 0 | 0 | 6/6 seeds PASS (table above) |
| chunk-8 standalone selftest | `merges/chunk8-selftest-2.log` | 0 | 0 | `DEEPFALL_SELFTEST_CHUNK8 done PASS=true` |
| full selftest | `merges/chunk8-full-selftest-2.log` | 0 | 0 | phases 6/7/8/9/9B/10/4 + CHUNK2 + CHUNK8 all PASS=true; `DEEPFALL_PHASE1_READY seed=20261101 rooms=40/40 ore_veins=87 spawn=(10, 44) exit=(190, 42) connected=true` |
| P11 (xvfb, no `--headless`) | `merges/chunk8-p11.log` | 0 | 0 | `DEEPFALL_P11 done hp=100 props=77` |

Quoted green lines (full selftest):
`DEEPFALL_SELFTEST_PHASE6 done a=true a3=true c_legacy=true c_stream=true b=true`
`DEEPFALL_SELFTEST_PHASE7 done PASS=true`
`DEEPFALL_SELFTEST_PHASE8 done PASS=true`
`DEEPFALL_SELFTEST_PHASE9 done PASS=true`
`DEEPFALL_SELFTEST_PHASE9B done PASS=true`
`DEEPFALL_SELFTEST_PHASE10 done PASS=true`
`DEEPFALL_SELFTEST_PHASE4 done PASS=true`
`DEEPFALL_SELFTEST_CHUNK2 done PASS=true`
`DEEPFALL_SELFTEST_CHUNK8 done PASS=true`
`DEEPFALL_SELFTEST done`
Phase 4 crystal line (ore is scarcer now but still within budget):
`DEEPFALL_SELFTEST_PHASE4 crystals count=20 budget=20 veins=34 veins_used=20 rule_violations=0 dupes=0`
(The single `DEEPFALL_CRAFT_FAIL id=lantern reason=needs_workbench` line in the
log is phase 7's deliberate negative-path check, not a failure.)

## Changed files (worktree vs live tree, `diff -rq`)

- `scripts/map_gen.gd` — ore banding (a).
- `scripts/main.gd` — overlay layers + rules (b), terrain mask wiring +
  runtime painter + chunk-8 selftests + flood-fill CI + dispatch (c, d);
  Phase 10 layer-count gate 312 → 390 (78 chunks × 5, overlay counted).
- `assets/atlas3/terrain_atlas.png` (+ `.import`) — new, composited from
  existing rock/dirt variants.
- `deepfall_terrain.tres` — new, built by `scripts/build_chunk8_terrain.gd`.
- `scripts/build_chunk8_terrain.gd` (+ `.uid`) — new builder script.
- `CHUNK8-REPORT.md` — this file.
- P11 screenshot PNGs in the worktree were overwritten by the P11 run and
  restored from the live tree, so they are not part of this change.

## Open decisions (Skit's call)

1. **Bands 20/50 vs suggested 30/60.** 30/60 was measured and rejected
   (amber = 5 cells on the reference seed). 20/50 is implemented. If he
   wants different thresholds, it is one constant pair in `map_gen.gd`.
2. **Ore economy.** Total precious ore is down ~35–45% (shallow veins are
   stone now): a full clear yields ~15–40 gold cells and ~23–35 amber cells
   per seed, vs ~32–47 gold / ~35–58 amber before. Crafting costs are
   unchanged. Balance call.
3. **Overlay path art.** `dirt_v0.png` as the path tile is a full opaque
   dirt tile drawn over stone — it reads as a worn dirt patch. If it reads
   as a hole or a mistake in play, swap the art or tighten the path rule.
4. **Terrain-mask render.** Rock/dirt interiors now all render variant 15
   (fully surrounded) instead of the old hash-varied rows — less visual
   noise variety, more readable edges. If it looks flat, the mask→variant
   art mapping (which `rock_N`/`dirt_N` image sits at which mask) can be
   permuted in the atlas/`.tres` without code changes. Special
   transition/corner art is unchanged.
5. **Phase 10 gate.** Updated 312 → 390 to count the overlay layers; the
   invariant (one layer array per chunk per kind) is preserved, the
   expectation was updated, not waived.
6. **Shift I** is still out of scope and unbuilt, as briefed.
