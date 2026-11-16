# build_chunk8_terrain.gd — Chunk 8 (c) one-shot builder for
# deepfall_terrain.tres. Run AFTER an editor import (the atlas PNG must
# be imported first so load() works):
#   godot --path . --headless --audio-driver Dummy --script res://scripts/build_chunk8_terrain.gd
# Builds: TileSet, tile_size 64, one Terrain Set (Match Sides), terrains
# rock (0) / dirt (1), 32 tiles — (mask 0..15, row 0 rock / row 1 dirt).
# Tile (mask, row) has peering bits encoding its mask: bit set => that
# side expects the same terrain, bit clear => empty terrain (-1).
# The atlas PNG itself is composited from the existing rock_*/dirt_*
# variants (see CHUNK8-REPORT.md) — no new sprites.
# Re-runnable: overwrites res://deepfall_terrain.tres. Prints a per-tile
# verification and exits 0 on success, 1 on any mismatch.
extends SceneTree

func _init() -> void:
	var ok := true
	var tex: Texture2D = load("res://assets/atlas3/terrain_atlas.png")
	if tex == null:
		print("CHUNK8_TERRAIN_BUILD FAIL could not load res://assets/atlas3/terrain_atlas.png (run editor import first)")
		quit(1)
		return
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(64, 64)
	tileset.add_terrain_set()
	tileset.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_SIDES)
	tileset.add_terrain(0)
	tileset.set_terrain_name(0, 0, "rock")
	tileset.set_terrain_color(0, 0, Color(0.55, 0.55, 0.58))
	tileset.add_terrain(0)
	tileset.set_terrain_name(0, 1, "dirt")
	tileset.set_terrain_color(0, 1, Color(0.55, 0.42, 0.28))
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(64, 64)
	tileset.add_source(src)
	var sides := [TileSet.CELL_NEIGHBOR_TOP_SIDE, TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
		TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, TileSet.CELL_NEIGHBOR_LEFT_SIDE]
	var bits := [1, 2, 4, 8]
	for row in range(2):
		for mask in range(16):
			var coord := Vector2i(mask, row)
			src.create_tile(coord, Vector2i(1, 1))
			var td: TileData = src.get_tile_data(coord, 0)
			td.terrain_set = 0
			td.terrain = row
			for i in range(4):
				td.set_terrain_peering_bit(sides[i], row if (mask & bits[i]) != 0 else -1)
	# Verify: read back every tile and confirm terrain + peering bits.
	for row in range(2):
		for mask in range(16):
			var coord := Vector2i(mask, row)
			var td: TileData = src.get_tile_data(coord, 0)
			if td.terrain_set != 0 or td.terrain != row:
				print("CHUNK8_TERRAIN_BUILD FAIL tile=%s terrain_set=%d terrain=%d (expect 0, %d)" % [str(coord), td.terrain_set, td.terrain, row])
				ok = false
			for i in range(4):
				var want: int = row if (mask & bits[i]) != 0 else -1
				var got: int = td.get_terrain_peering_bit(sides[i])
				if got != want:
					print("CHUNK8_TERRAIN_BUILD FAIL tile=%s side=%d got=%d want=%d" % [str(coord), sides[i], got, want])
					ok = false
	if not ok:
		quit(1)
		return
	var err: int = ResourceSaver.save(tileset, "res://deepfall_terrain.tres")
	if err != OK:
		print("CHUNK8_TERRAIN_BUILD FAIL ResourceSaver.save err=%d" % err)
		quit(1)
		return
	print("CHUNK8_TERRAIN_BUILD OK tiles=32 terrains=rock,dirt mode=Match_Sides file=res://deepfall_terrain.tres")
	quit(0)
