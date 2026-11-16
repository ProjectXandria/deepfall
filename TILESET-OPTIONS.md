# TileSet options memo — DEEPFALL chunk 2

Prepared 2026-11-14. No pick is made here: both paths are staged, with
costs, risks, and what each unlocks. Skit decides.

## First, what "the 16-tile atlas" actually is

The phrase is ambiguous, and the three things it could mean are all real:

1. **atlas3 rock/dirt, 16 variants each — already wired.** `assets/atlas3/rock_0..15.png`
   and `dirt_0..15.png` are the live fill art. `VARIANT_COUNTS` gives stone 16 and
   dirt 16, and `_build_tileset()` (scripts/main.gd) stitches them into the
   runtime atlas alongside the walls, the 16 Phase 9 transition/corner tiles,
   the 8 chunk-2 inner-corner tiles, and the 17 chunk-2 slope/half/stair tiles
   (56 columns × 16 rows). Selection is a pure function in `_fill_special()` /
   `_render_layers_and_edges()` — no Godot terrain sets are involved today.
2. **Staged `atlas-tiles/` sets, 4 variants each — not wired.** 
   `~/workspace/asset-pipeline/staging/deepfall/tiles-real/atlas-tiles/` holds
   `cave-0..3`, `dirt-stone-0..3`, `techfloor-0..3`, `wasteland-0..3` (+ a
   `proof-techfloor-3x3.png`) with a `MANIFEST.json` of edge metrics
   (`edge_lr` / `edge_tb`, roughly 1.4–7.0). These are candidate fill sets for
   other materials/regions, not the live Mines fills.
3. **VISUAL-SPEC §4's terrain-set design — the target, not the state.**
   One terrain set per material (`rock`, `dirt`); each set holds 4 fill
   variants, 4 straight edges, 4 outer corners, 4 inner corners, and the
   rock↔dirt transition set, with peering bits assigned from the grid
   (the standard blob pattern, cut down to what Mines needs). Edge overlays
   stay a separate visual layer (§4.3). Slopes stay out of the terrain sets
   (§4.4) — they are custom tiles with mirrored collision, which chunk 2
   just wired.

So "wire the 16-tile atlas" means: take the art in (1) — which the game
already renders through custom selection — and move its *selection* onto
Godot's terrain system, per (3). It is a selection-logic migration, not an
art migration. The art is already there.

## Path (a): wire terrain sets (Godot-native autotiling)

**Scope.** Build the TileSet with terrain sets instead of (or alongside) the
current stitched atlas: one terrain set ("ground"), two terrains (rock,
dirt), tiles for fills / transitions / outer corners / inner corners with
peering bits per the mapping below. Replace `_fill_special()` selection for
the fill layer with `TileMapLayer.set_cells_terrain_connect()` on rebuild,
and re-run terrain updates on the 3×3 neighbourhood in `_mine_at()` instead
of `_set_fill_cell()` / `_update_edge()`. Keep the edge-overlay layer and
the damage layer exactly as they are (VISUAL-SPEC §4.3 keeps overlays
separate). Slopes stay custom tiles with the chunk-2 heightfield collision.

**Peering-bit mapping** (`TERRAIN_MODE_MATCH_CORNERS_AND_SIDES`; `-1` = empty/air):

| Tile | Sides / corners |
|---|---|
| Fill (rock or dirt) | all 8 bits = own terrain |
| Straight transition, e.g. `trans_rock_N` | N side + its two corners = other terrain, rest own |
| Outer corner, e.g. `corner_rock_TL` | N + W sides and the TL corner = -1, rest own |
| Inner corner, e.g. `inner_rock_NE` | NE corner = -1, rest own |

Chunk 2's new art already fits this mapping 1:1 — the inner-corner tiles
are exactly the "one corner = -1" case, and the transition tiles are
exactly the "one side = other terrain" case. No new art is needed for (a).

**Cost.** ~1–2 days: terrain-set construction ~half a day; migrating
selection + mining re-derivation ~half a day; verification ~half a day
(the seed-diff proof must be redone from scratch, and `terrain_connect`
on 18,000 cells per rebuild needs a perf measurement on the S25 target).

**Risks.**
- Engine-side selection replaces the pure-function selection. The
  seed-20261101 pixel-identical guarantee must be re-proven cell by cell;
  any mismatch is a render regression, not a logic one, and is harder to
  diff than a `_fill_special` change.
- The bulk renderer (`_render_layers_and_edges`) is a hand-rolled
  optimisation that `terrain_connect` would partially replace. Perf on
  rebuild could go either way; it is unmeasured until tried.
- The runtime-stitched atlas would need restructuring (terrain sources
  instead of one big atlas), which touches `_build_tileset()` and every
  place that assumes atlas column numbers (notably `_fill_special`'s
  `base_col` arithmetic and the dump-layers diff workflow).

**Unlocks.** Godot-native autotiling (less custom selection code to
maintain); an editor-visible TileSet (terrain can be painted and tested
in-editor instead of only through the seed); a third material becomes a
new terrain + tiles with no new selection code (matters for Fungal
Hollows, whose spore-stone/spore-dirt/damp-stone would otherwise need
another `_fill_special` family branch).

**Staging done.** This memo + the mapping table above. No code in the
tree is committed to (a): the render path still runs on `_fill_special`.

## Path (b): more variants per ground type

**Scope.** Generate more fill variants procedurally (PIL, same pattern as
Phase 9 and chunk 2's `build_chunk2_assets.py`): rock/dirt 16 → 24, and
give the 4-variant materials real variety — mossy-stone, cracked-stone,
obsidian, sand, wood, brick. Only `VARIANT_COUNTS` changes plus the art
files; the `_variant()` block hash already spreads variants, and no
selection logic changes. Atlas height grows past 16 rows if any material
exceeds 16 variants (currently 16 rows tall) — a one-line change in
`_build_tileset()`.

**Cost.** ~half a day: art-gen script + counts + verification (seed-diff
must still be re-run, but the selection logic is untouched so the diff
should show only variant-row changes on fill cells).

**Risks.** Low. No logic change; atlas memory is trivial (each variant is
one 64×64 tile). What it does *not* fix: repetition is reduced, not
removed — large flat areas still read as a grid at a glance, and it adds
no new terrain behaviour.

**Unlocks.** The cheapest visible-richness win; more distinct material
reads (mossy vs cracked vs obsidian stop sharing the same 4 variants);
and it is a strict subset of the work path (a) keeps — the new variants
become terrain-set fill tiles if (a) happens later.

## Order note (not a pick)

(b) first is cheap and keeps (a) fully open. (a) first makes (b) slightly
redundant, since variants would be re-laid-out as terrain fills anyway.
Either order is reversible at the file level; neither touches the save
format, the collision grid, or the seed.

## Open questions for Skit

1. (a) or (b) — or (b) now and (a) after Game Off?
2. If (a): does the edge-overlay layer stay separate (VISUAL-SPEC §4.3
   says yes), and is a terrain_connect perf measurement on the S25 part
   of the acceptance bar?
3. If (b): which materials get variants first, and is 24 the right cap
   for rock/dirt (vs matching the staged `atlas-tiles/` 4-variant sets)?
