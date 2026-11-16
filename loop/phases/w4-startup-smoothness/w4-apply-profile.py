#!/usr/bin/env python3
"""W4: add --profile gated stage timing to scratch main.gd (NOT the live tree yet).
Prints cumulative W4_STAGE <name> ms=<n> lines from _ready start. Run with
--profile --seed=20261101 --screenshot. No output at all without --profile.
Idempotent-ish: fails loudly if an anchor is not found exactly once.
"""
import sys
P = "/home/hatch/workspace/goals/game-off-2026-entry/loop-scratch/w4-startup-smoothness/scripts/main.gd"
src = open(P).read()

def once(old, new):
    global src
    n = src.count(old)
    assert n == 1, "anchor found %d times: %r" % (n, old[:80])
    src = src.replace(old, new)

# --- helper + state, right after the _ready t0 line ---
once("""func _ready() -> void:
\tvar _t0 := Time.get_ticks_msec()
""", """# W4 profiling: --profile prints cumulative ms per startup stage
# (W4_STAGE <name> ms=<n>, from _ready entry). Dormant otherwise.
var _w4_prof := false
var _w4_t0 := 0
func _w4_prof_begin() -> void:
\t_w4_prof = "--profile" in OS.get_cmdline_user_args()
\t_w4_t0 = Time.get_ticks_msec()
func _w4_prof_mark(stage: String) -> void:
\tif _w4_prof:
\t\tprint("W4_STAGE %s ms=%d" % [stage, Time.get_ticks_msec() - _w4_t0])

func _ready() -> void:
\tvar _t0 := Time.get_ticks_msec()
\t_w4_prof_begin()
""")

# --- _ready stage marks ---
once("""\t_show_loading("DIGGING THE MINES…")
\tawait get_tree().process_frame
\tawait get_tree().process_frame
\tawait _rebuild_world(true, true)
""", """\t_show_loading("DIGGING THE MINES…")
\t_w4_prof_mark("ready_loading_shown")
\tawait get_tree().process_frame
\tawait get_tree().process_frame
\t_w4_prof_mark("ready_frames")
\tawait _rebuild_world(true, true)
\t_w4_prof_mark("ready_rebuild")
""")
once("""\t_render_background()
\tvar exit_cell: Vector2i = data["exit"]
""", """\t_render_background()
\t_w4_prof_mark("ready_background")
\tvar exit_cell: Vector2i = data["exit"]
""")
once("""\t_build_craft_panel()
\t_build_class_select()
""", """\t_build_craft_panel()
\t_w4_prof_mark("ready_craft")
\t_build_class_select()
\t_w4_prof_mark("ready_class")
""")
once("""\tlog_event("Tool: Pickaxe")
""", """\t_w4_prof_mark("ready_hud")
\tlog_event("Tool: Pickaxe")
""")

# --- _rebuild_world stage marks ---
once("""\t_clear_dynamic()
\tdata = DeepfallMapGen.generate(run_seed)
""", """\t_clear_dynamic()
\t_w4_prof_mark("rebuild_clear")
\tdata = DeepfallMapGen.generate(run_seed)
\t_w4_prof_mark("rebuild_generate")
""")
once("""\t_build_polished_chamber()
\tore_collected = 0
""", """\t_build_polished_chamber()
\t_w4_prof_mark("rebuild_chamber_gen")
\tore_collected = 0
""")
once("""\tif not _tileset_built:
\t\t_build_tileset()
\t\t_create_chunk_layers()
\t\t_tileset_built = true
""", """\tif not _tileset_built:
\t\t_build_tileset()
\t\t_w4_prof_mark("rebuild_tileset")
\t\t_create_chunk_layers()
\t\t_tileset_built = true
\t\t_w4_prof_mark("rebuild_chunks")
""")
once("""\t_render_layers()
\t_render_edges()
""", """\t_render_layers()
\t_w4_prof_mark("rebuild_layers")
\t_render_edges()
\t_w4_prof_mark("rebuild_edges")
""")
once("""\t_build_enemy_spawn_table()
""", """\t_w4_prof_mark("rebuild_props")
\t_build_enemy_spawn_table()
\t_w4_prof_mark("rebuild_enemies")
""")
once("""\t_apply_chunk_visibility(true)
\tif staged:
\t\tawait get_tree().process_frame
""", """\t_apply_chunk_visibility(true)
\t_w4_prof_mark("rebuild_stream")
\tif staged:
\t\tawait get_tree().process_frame
""")

open(P, "w").write(src)
print("profile instrumentation applied OK")
