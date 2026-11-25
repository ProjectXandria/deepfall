#!/usr/bin/env python3
"""W4 optimisation (scratch): merged layers+edges pass, ore-scan fold-in,
load hoists, tileset convert-guard. World output must stay identical —
verified by --dump-layers diff on 3 seeds before/after.
"""
P = "/home/hatch/workspace/goals/game-off-2026-entry/loop-scratch/w4-startup-smoothness/scripts/main.gd"
src = open(P).read()

def once(old, new):
    global src
    n = src.count(old)
    assert n == 1, "anchor x%d: %r" % (n, old[:80])
    src = src.replace(old, new)

# ---- 1. merged pass: replace the two calls in _rebuild_world ----
once("""\t_render_layers()
\t_w4_prof_mark("rebuild_layers")
\t_render_edges()
\t_w4_prof_mark("rebuild_edges")
""", """\t_render_layers_and_edges()
\t_w4_prof_mark("rebuild_layers_edges")
""")

# ---- 2. replace _render_layers with the merged pass; delete _render_edges ----
# _render_layers runs 1984..1993 (before _is_solid_cell); _render_edges runs
# 2064..2068 (before _render_props). _is_solid_cell/_is_air/_edge_for_cell/
# _update_edge stay: _set_fill_cell/_update_edge are the runtime single-cell
# paths used when mining re-derives neighbours.
i0 = src.index("func _render_layers() -> void:")
i1 = src.index("func _is_solid_cell(c: Vector2i) -> bool:")
old_layers = src[i0:i1]
assert "for y in range(DeepfallMapGen.H):" in old_layers
j0 = src.index("func _render_edges() -> void:")
j1 = src.index("func _render_props() -> void:")
old_edges = src[j0:j1]
assert "_update_edge(Vector2i(x, y))" in old_edges

merged = '''# W4: merged bulk render pass. One 200x90 sweep replaces _render_layers +
# _render_edges: the neighbour air/solid mask and material groups are
# computed once per cell and shared by the fill, wall and edge decisions
# (the old code re-derived them in _fill_special, _variant and
# _edge_for_cell, called _fill_special twice per solid cell, and walked
# the grid twice with a Vector2i alloc + _stream_chunk_of call per cell).
# Output is identical to the two old passes — verified by --dump-layers
# diff on 3 seeds. Chunk layers are indexed arithmetically (in-bounds
# cells never need the clamp in _stream_chunk_of). Ore cells are
# collected in the same scan order _render_props used, so its own 18k
# sweep is gone. _set_fill_cell / _update_edge (single-cell, used when
# mining re-derives neighbours) are untouched.
var _bulk_ore_cells: Array = []
const _MAT_GROUP_LUT := [3, 1, 1, 0, 2, 2, 3, 3, 3, 0, 0, 1, 0, 2]
# tile id -> _mat_group: 0 stone fam {3,9,10,12}, 1 dirt fam {1,2,11},
# 2 ore {4,5,13}, 3 other. Id 0 (air) is never looked up.

func _render_layers_and_edges() -> void:
\t_bulk_ore_cells.clear()
\tvar W := DeepfallMapGen.W
\tvar H := DeepfallMapGen.H
\tfor y in range(H):
\t\tvar ci_base := (y / STREAM) * STREAM_COLS
\t\tfor x in range(W):
\t\t\tvar t: int = fg[y][x]
\t\t\tvar ci := ci_base + x / STREAM
\t\t\tvar c := Vector2i(x, y)
\t\t\t# Neighbour fg (borders read as stone: _is_solid_cell is true
\t\t\t# out of bounds, _is_air false — the _in flags gate the
\t\t\t# transition checks exactly like the old bounds checks).
\t\t\tvar n_in := y > 0
\t\t\tvar e_in := x + 1 < W
\t\t\tvar s_in := y + 1 < H
\t\t\tvar w_in := x > 0
\t\t\tvar n_fg: int = fg[y - 1][x] if n_in else 3
\t\t\tvar e_fg: int = fg[y][x + 1] if e_in else 3
\t\t\tvar s_fg: int = fg[y + 1][x] if s_in else 3
\t\t\tvar w_fg: int = fg[y][x - 1] if w_in else 3
\t\t\tvar n_air := n_in and n_fg == 0
\t\t\tvar e_air := e_in and e_fg == 0
\t\t\tvar s_air := s_in and s_fg == 0
\t\t\tvar w_air := w_in and w_fg == 0
\t\t\t# _is_solid_cell: in-bounds fg != 0 and != 7 (platform is
\t\t\t# not solid); out of bounds counts as solid.
\t\t\tvar n_solid := (not n_in) or (n_fg != 0 and n_fg != 7)
\t\t\tvar e_solid := (not e_in) or (e_fg != 0 and e_fg != 7)
\t\t\tvar s_solid := (not s_in) or (s_fg != 0 and s_fg != 7)
\t\t\tvar w_solid := (not w_in) or (w_fg != 0 and w_fg != 7)
\t\t\tvar mask := (1 if n_air else 0) + (2 if e_air else 0) + (4 if s_air else 0) + (8 if w_air else 0)
\t\t\tvar cell_solid := t != 0 and t != 7
\t\t\t# --- fill (was _set_fill_cell) ---
\t\t\tvar sp := -1
\t\t\tif t == 0:
\t\t\t\t_fg_layers[ci].erase_cell(c)
\t\t\telse:
\t\t\t\tvar g: int = _MAT_GROUP_LUT[t]
\t\t\t\tif g == 0 or g == 1:
\t\t\t\t\t# material transition first (dirs N,E,S,W, like
\t\t\t\t\t# _fill_special); each direction only if in bounds,
\t\t\t\t\t# solid, and the other family (rock vs dirt).
\t\t\t\t\tvar ngn: int = -1
\t\t\t\t\tif n_in and n_solid:
\t\t\t\t\t\tngn = _MAT_GROUP_LUT[n_fg]
\t\t\t\t\t\tif (g == 0 and ngn == 1) or (g == 1 and ngn == 0):
\t\t\t\t\t\t\tsp = 15 + (0 if g == 0 else 4)
\t\t\t\t\tif sp < 0 and e_in and e_solid:
\t\t\t\t\t\tvar nge: int = _MAT_GROUP_LUT[e_fg]
\t\t\t\t\t\tif (g == 0 and nge == 1) or (g == 1 and nge == 0):
\t\t\t\t\t\t\tsp = 15 + (1 if g == 0 else 5)
\t\t\t\t\tif sp < 0 and s_in and s_solid:
\t\t\t\t\t\tvar ngs: int = _MAT_GROUP_LUT[s_fg]
\t\t\t\t\t\tif (g == 0 and ngs == 1) or (g == 1 and ngs == 0):
\t\t\t\t\t\t\tsp = 15 + (2 if g == 0 else 6)
\t\t\t\t\tif sp < 0 and w_in and w_solid:
\t\t\t\t\t\tvar ngw: int = _MAT_GROUP_LUT[w_fg]
\t\t\t\t\t\tif (g == 0 and ngw == 1) or (g == 1 and ngw == 0):
\t\t\t\t\t\t\tsp = 15 + (3 if g == 0 else 7)
\t\t\t\t\tif sp < 0:
\t\t\t\t\t\tvar corner_off := -1
\t\t\t\t\t\tif n_air and w_air:
\t\t\t\t\t\t\tcorner_off = 0
\t\t\t\t\t\telif n_air and e_air:
\t\t\t\t\t\t\tcorner_off = 1
\t\t\t\t\t\telif s_air and w_air:
\t\t\t\t\t\t\tcorner_off = 2
\t\t\t\t\t\telif s_air and e_air:
\t\t\t\t\t\t\tcorner_off = 3
\t\t\t\t\t\tif corner_off >= 0:
\t\t\t\t\t\t\tsp = 15 + 8 + (corner_off if g == 0 else 4 + corner_off)
\t\t\t\tif sp >= 0:
\t\t\t\t\t_fg_layers[ci].set_cell(c, 0, Vector2i(sp, 0))
\t\t\t\telse:
\t\t\t\t\tvar idx: int = FG_TO_ATLAS.get(t, 2)
\t\t\t\t\tvar nvar: int = VARIANT_COUNTS.get(TILE_NAMES[idx], 4)
\t\t\t\t\t_fg_layers[ci].set_cell(c, 0, Vector2i(idx, (mask * 3 + (x / 4 + y / 4)) % nvar))
\t\t\t\tif t == 4 or t == 5:
\t\t\t\t\t_bulk_ore_cells.append(c)
\t\t\t# --- wall (was _render_layers tail) ---
\t\t\tvar wv: int = wall[y][x]
\t\t\tif wv != 0:
\t\t\t\tvar idx2: int = WALL_TO_ATLAS[wv]
\t\t\t\t_wall_layers[ci].set_cell(c, 0, Vector2i(idx2, (mask * 3 + (x / 4 + y / 4)) % 4))
\t\t\t# --- edge (was _update_edge / _edge_for_cell) ---
\t\t\tvar e := -1
\t\t\tif cell_solid:
\t\t\t\tif sp < 0:
\t\t\t\t\tvar own: int = _MAT_GROUP_LUT[t]
\t\t\t\t\tvar done := false
\t\t\t\t\tif own != 2:
\t\t\t\t\t\t# transition (dirs N,S,W,E, like _edge_for_cell)
\t\t\t\t\t\tif n_in and n_solid and _MAT_GROUP_LUT[n_fg] != own:
\t\t\t\t\t\t\te = 0
\t\t\t\t\t\t\tdone = true
\t\t\t\t\t\telif s_in and s_solid and _MAT_GROUP_LUT[s_fg] != own:
\t\t\t\t\t\t\te = 1
\t\t\t\t\t\t\tdone = true
\t\t\t\t\t\telif w_in and w_solid and _MAT_GROUP_LUT[w_fg] != own:
\t\t\t\t\t\t\te = 2
\t\t\t\t\t\t\tdone = true
\t\t\t\t\t\telif e_in and e_solid and _MAT_GROUP_LUT[e_fg] != own:
\t\t\t\t\t\t\te = 3
\t\t\t\t\t\t\tdone = true
\t\t\t\t\tif not done:
\t\t\t\t\t\tif n_air and w_air:
\t\t\t\t\t\t\te = 4
\t\t\t\t\t\telif n_air and e_air:
\t\t\t\t\t\t\te = 5
\t\t\t\t\t\telif s_air and w_air:
\t\t\t\t\t\t\te = 6
\t\t\t\t\t\telif s_air and e_air:
\t\t\t\t\t\t\te = 7
\t\t\t\t\t\telif n_air:
\t\t\t\t\t\t\te = 0
\t\t\t\t\t\telif s_air:
\t\t\t\t\t\t\te = 1
\t\t\t\t\t\telif w_air:
\t\t\t\t\t\t\te = 2
\t\t\t\t\t\telif e_air:
\t\t\t\t\t\t\te = 3
\t\t\telse:
\t\t\t\t# air cell (a platform counts as air here, like _edge_for_cell)
\t\t\t\tif n_solid and w_solid:
\t\t\t\t\te = 4
\t\t\t\telif n_solid and e_solid:
\t\t\t\t\te = 5
\t\t\t\telif s_solid and w_solid:
\t\t\t\t\te = 6
\t\t\t\telif s_solid and e_solid:
\t\t\t\t\te = 7
\t\t\tif e < 0:
\t\t\t\t_edge_layers[ci].erase_cell(c)
\t\t\telse:
\t\t\t\t_edge_layers[ci].set_cell(c, 0, Vector2i(e, 0))

'''
src = src[:i0] + merged + src[i1:]
# re-find _render_edges after the splice (indices shifted)
j0 = src.index("func _render_edges() -> void:")
j1 = src.index("func _render_props() -> void:")
src = src[:j0] + src[j1:]

# ---- 3. _render_props: use the merged pass's ore list, hoist loads ----
once("""func _render_props() -> void:
\tvar spawn: Vector2i = data["spawn"]
""", """func _render_props() -> void:
\t# W4: timber textures loaded once per rebuild, not once per post.
\tvar post_tex: Texture2D = load("res://assets/atlas3/timber_post.png")
\tvar trestle_tex: Texture2D = load("res://assets/atlas3/timber_trestle.png")
\tvar spawn: Vector2i = data["spawn"]
""")
once("""\t\t\tvar post := Sprite2D.new()
\t\t\tpost.texture = load("res://assets/atlas3/timber_post.png")
""", """\t\t\tvar post := Sprite2D.new()
\t\t\tpost.texture = post_tex
""")
once("""\t\t\t\tvar tres := Sprite2D.new()
\t\t\t\ttres.texture = load("res://assets/atlas3/timber_trestle.png")
""", """\t\t\t\tvar tres := Sprite2D.new()
\t\t\t\ttres.texture = trestle_tex
""")
once("""\t# crystal clusters: cyan diamond + light in an air cell beside an ore cell
\tvar ore_cells: Array = []
\tfor y in range(DeepfallMapGen.H):
\t\tfor x in range(DeepfallMapGen.W):
\t\t\tif fg[y][x] == 4 or fg[y][x] == 5:
\t\t\t\tore_cells.append(Vector2i(x, y))
""", """\t# crystal clusters: cyan diamond + light in an air cell beside an ore cell
\t# W4: ore cells come from the merged render pass (same y-then-x scan
\t# order) instead of a second full-grid sweep here.
\tvar ore_cells: Array = _bulk_ore_cells
""")

# ---- 4. _render_chamber: hoist loads ----
once("""func _render_chamber() -> void:
""", """func _render_chamber() -> void:
\t# W4: textures loaded once per rebuild, not once per prop.
\tvar post_tex: Texture2D = load("res://assets/atlas3/timber_post.png")
\tvar torch_tex: Texture2D = load("res://assets/torch.png")
""")
n = src.count('\t\tpost.texture = load("res://assets/atlas3/timber_post.png")')
assert n == 1, "chamber post loads %d" % n
src = src.replace("""\t\tpost.texture = load("res://assets/atlas3/timber_post.png")""", """\t\tpost.texture = post_tex""")
n = src.count('\t\tstick.texture = load("res://assets/torch.png")')
assert n == 1, "chamber torch loads %d" % n
src = src.replace("""\t\tstick.texture = load("res://assets/torch.png")""", """\t\tstick.texture = torch_tex""")
n = src.count('gpost.texture = load("res://assets/atlas3/timber_post.png")')
assert n == 1, "gate post loads %d" % n
src = src.replace("""\t\t\t\tgpost.texture = load("res://assets/atlas3/timber_post.png")""", """\t\t\t\tgpost.texture = post_tex""")
assert src.count('load("res://assets/atlas3/timber_post.png")') == 2, "timber_post loads left: %d" % src.count('load("res://assets/atlas3/timber_post.png")')
assert src.count('load("res://assets/torch.png")') == 2, "torch loads left: %d" % src.count('load("res://assets/torch.png")')
# 2 = the chamber hoist local + the runtime torch at _place_torch_at (2490), left alone.

# ---- 5. _render_background: load the cave texture once ----
once("""\tvar cave := Sprite2D.new()
\tcave.texture = load("res://assets/atlas3/cave-silhouettes.png")
""", """\t# W4: one load shared by the three backdrop sprites.
\tvar cave_tex: Texture2D = load("res://assets/atlas3/cave-silhouettes.png")
\tvar cave := Sprite2D.new()
\tcave.texture = cave_tex
""")
src = src.replace("""\t_plx_far.texture = load("res://assets/atlas3/cave-silhouettes.png")""", """\t_plx_far.texture = cave_tex""")
src = src.replace("""\t_plx_mid.texture = load("res://assets/atlas3/cave-silhouettes.png")""", """\t_plx_mid.texture = cave_tex""")
assert src.count('load("res://assets/atlas3/cave-silhouettes.png")') == 1

# ---- 6. tileset: skip convert() when already RGBA8 ----
n = src.count("\tim.convert(Image.FORMAT_RGBA8)")
assert n == 2, "main/edge convert count %d" % n
# Two sites, different indentation: main atlas loop (3 tabs) and edge
# atlas loop (2 tabs). Guard both.
src = src.replace("""\t\t\tvar im: Image = tex.get_image()
\t\t\tim.convert(Image.FORMAT_RGBA8)""", """\t\t\tvar im: Image = tex.get_image()
\t\t\t# W4: convert() on an already-RGBA8 image still copies the
\t\t\t# whole 64x64; skip it when the format already matches.
\t\t\tif im.get_format() != Image.FORMAT_RGBA8:
\t\t\t\tim.convert(Image.FORMAT_RGBA8)""")
src = src.replace("""\t\tvar im: Image = tex.get_image()
\t\tim.convert(Image.FORMAT_RGBA8)""", """\t\tvar im: Image = tex.get_image()
\t\t# W4: convert() on an already-RGBA8 image still copies the
\t\t# whole 64x64; skip it when the format already matches.
\t\tif im.get_format() != Image.FORMAT_RGBA8:
\t\t\tim.convert(Image.FORMAT_RGBA8)""")
assert src.count("\tim.convert(Image.FORMAT_RGBA8)") == 2, "im.convert left unguarded"
assert src.count("if im.get_format() != Image.FORMAT_RGBA8:") == 2
n = src.count("dim.convert(Image.FORMAT_RGBA8)")
assert n == 1
src = src.replace("""\tvar dim: Image = dtex2.get_image()
\tdim.convert(Image.FORMAT_RGBA8)""", """\tvar dim: Image = dtex2.get_image()
\tif dim.get_format() != Image.FORMAT_RGBA8:
\t\tdim.convert(Image.FORMAT_RGBA8)""")

open(P, "w").write(src)
print("W4 optimisation applied OK")
