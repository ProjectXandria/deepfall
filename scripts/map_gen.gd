# map_gen.gd — DEEPFALL Phase 1 generation.
# Port of deepfall_map_gen.py, adapted to the Terraria block-grid model:
#  fg  = foreground mineable blocks (collision), 0 = air
#  wall = background wall grid (NO collision, rendered behind air)
#  platform cells are one-way (collision only when falling onto them).
# Tile ids (fg): 0 air, 1 dirt, 2 grass-dirt, 3 stone, 4 gold-ore, 5 amber-ore,
#  6 wood, 7 wood-platform, 8 brick, 9 mossy-stone, 10 cracked-stone,
#  11 sand, 12 obsidian, 13 coal-ore (Phase 7).
#  Wall: 0 none, 1 dirt-wall, 2 cave-wall-dark.
# Same seed = same world (single RandomNumberGenerator, fixed call order).
extends RefCounted
class_name DeepfallMapGen

# Phase 14: much larger world — same structured room+corridor
# algorithm (rooms, spanning-tree corridors, loop corridors), just
# a bigger map. The structure is what keeps it from being noise:
# rooms are placed non-overlapping, connected by corridors, and
# flood-fill validated. 200x90 with 40 rooms (was 80x45 / 14).
const W := 200
const H := 90
const AIR := 0
const PLATFORM := 7

# Chunk 8: depth-banded ore (Terraria report §8.2 step 1, DEEPFALL-original
# bands — Deepfall's own ore names, bands and thresholds, no Terraria
# numbers copied). Bands are a PURE function of cell y (ore_for_band):
#   y < 20: no precious ore (shallow workings, stone only)
#   20 <= y < 50: gold (4) — the middle workings
#   y >= 50: amber (5) — the deep workings
# Band choice (reason, from the 10-row ore histogram on 6 seeds in
# CHUNK8-REPORT.md): the first-suggested 30/60 split leaves only 5 amber
# cells on the reference seed 20261101 (its deep band y>=60 holds 5 ore
# cells total), so amber would be near-extinct in the reference world.
# The 20/50 split keeps gold >= 15 and amber >= 23 on every one of the
# 6 seeds while still giving a real no-ore shallows (top ~2 room rows).
const ORE_BAND_SHALLOW_END := 20
const ORE_BAND_GOLD_END := 50

static func ore_for_band(y: int) -> int:
	if y < ORE_BAND_SHALLOW_END:
		return 0
	if y < ORE_BAND_GOLD_END:
		return 4
	return 5

static func generate(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var fg: Array = []
	var wall: Array = []
	for _y in range(H):
		var fr: Array = []; fr.resize(W); fr.fill(3)  # stone default
		var wr: Array = []; wr.resize(W); wr.fill(0)
		fg.append(fr); wall.append(wr)
	# --- rooms (non-overlapping, sorted left -> right) ---
	var rooms: Array = []
	var tries := 0
	while rooms.size() < 40 and tries < 3000:
		tries += 1
		var rw := rng.randi_range(8, 16)
		var rh := rng.randi_range(6, 10)
		var rx := rng.randi_range(2, W - rw - 2)
		var ry := rng.randi_range(2, H - rh - 2)
		var overlap := false
		for o in rooms:
			if not (rx > o[0] + o[2] + 1 or rx + rw < o[0] - 1 or ry > o[1] + o[3] + 1 or ry + rh < o[1] - 1):
				overlap = true; break
		if overlap:
			continue
		rooms.append([rx, ry, rw, rh])
	rooms.sort_custom(func(a, b): return a[0] < b[0])
	var carve_room := func(r: Array) -> void:
		for yy in range(r[1], r[1] + r[3] - 1):  # leave bottom row solid = floor
			for xx in range(r[0], r[0] + r[2]):
				fg[yy][xx] = AIR
	# W3: vertical legs recorded by the corridor lambda (see below).
	var vlegs: Array = []
	var corridor := func(a: Array, b: Array) -> void:
		var ax: int = int(a[0]) + int(a[2]) / 2; var ay: int = int(a[1]) + int(a[3]) / 2
		var bx: int = int(b[0]) + int(b[2]) / 2; var by: int = int(b[1]) + int(b[3]) / 2
		# W3: record the vertical leg (3-wide shaft at bx..bx+2,
		# rows min(ay,by)..max(ay,by)) so climb ledges can be added
		# after all carving, including repair corridors.
		vlegs.append([bx, mini(ay, by), maxi(ay, by)])
		for xx in range(min(ax, bx), max(ax, bx) + 1):
			for dy in range(3):
				if ay + dy < H:
					fg[ay + dy][xx] = AIR
		for yy in range(min(ay, by), max(ay, by) + 1):
			for dx in range(3):
				if bx + dx < W:
					fg[yy][bx + dx] = AIR
	for r in rooms:
		carve_room.call(r)
	# --- spanning tree + 8 loop corridors ---
	var connected: Array = [rooms[0]]
	for r in rooms.slice(1):
		var near: Array = connected[0]
		var best := 99999
		for o in connected:
			var d: int = abs(int(o[0]) - int(r[0])) + abs(int(o[1]) - int(r[1]))
			if d < best:
				best = d; near = o
		corridor.call(near, r)
		connected.append(r)
	for _i in range(8):
		var a: Array = rooms[rng.randi_range(0, rooms.size() - 1)]
		var b: Array = rooms[rng.randi_range(0, rooms.size() - 1)]
		if abs(a[0] - b[0]) > 20:
			corridor.call(a, b)
	# --- platforms in tall rooms ---
	for r in rooms:
		if r[3] >= 8:
			var px: int = int(r[0]) + 2
			while px < r[0] + r[2] - 2:
				var py: int = int(r[1]) + 3
				if fg[py][px] == AIR:
					for dx in range(3):
						if px + dx < r[0] + r[2]:
							fg[py][px + dx] = PLATFORM
				px += 5
	# --- ore veins: connected random walks in solid cells above rooms ---
	var ore_count := 0
	for i in range(rooms.size()):
		if i == 0:
			continue  # never in spawn room
		var r: Array = rooms[i]
		for _v in range(rng.randi_range(1, 2)):
			var vx: int = int(r[0]) + rng.randi_range(0, int(r[2]) - 1)
			var vy: int = int(r[1]) - 1
			for _s in range(rng.randi_range(4, 9)):
				if vx >= 0 and vx < W and vy >= 0 and vy < H and fg[vy][vx] != AIR and fg[vy][vx] != PLATFORM:
					# Chunk 8: the flat coin flip is GONE as a decision,
					# but its RNG call is KEPT (discarded into _flip) so
					# the RNG stream — and therefore the coal/wood veins,
					# which read the same stream after this pass — stays
					# byte-identical. The ore TYPE is a pure function of
					# the cell's y band (ore_for_band): room layout,
					# corridors and walk geometry are unchanged; only ore
					# type per cell moves. Shallow cells (band 0) stay
					# stone: no placement, no ore_count increment, walk
					# continues as before.
					var _flip: int = rng.randi_range(0, 1)
					var band_ore: int = ore_for_band(vy)
					if band_ore != 0:
						fg[vy][vx] = band_ore
						ore_count += 1
				vx += rng.randi_range(-1, 1)
				vy += rng.randi_range(0, 1)
	# --- Phase 7: coal + wood veins (connected random walks, same shape
	# as the ore veins, AFTER them so the ore count / READY line is
	# untouched). Solid-to-solid only (never air/platform/ore), so
	# topology, flood-fill and spawn/exit are unchanged. Coal and wood
	# are the Phase 7 crafting materials: coal-ore (13) and wood (6)
	# were never generated before this phase — wood blocks in
	# particular existed as a tile id but with zero cells in the world,
	# which would have made torch crafting impossible.
	var coal_count := 0
	for _cv in range(20):
		var cr: Array = rooms[rng.randi_range(1, rooms.size() - 1)]
		var cx: int = int(cr[0]) + rng.randi_range(0, int(cr[2]) - 1)
		var cy: int = int(cr[1]) - 1
		for _s in range(rng.randi_range(4, 7)):
			if cx >= 0 and cx < W and cy >= 0 and cy < H and fg[cy][cx] != AIR and fg[cy][cx] != PLATFORM and fg[cy][cx] != 4 and fg[cy][cx] != 5 and fg[cy][cx] != 13:
				fg[cy][cx] = 13
				coal_count += 1
			cx += rng.randi_range(-1, 1)
			cy += rng.randi_range(-1, 1)
	var wood_count := 0
	for _wv in range(26):
		var wr2: Array = rooms[rng.randi_range(1, rooms.size() - 1)]
		var wx: int = int(wr2[0]) + rng.randi_range(0, int(wr2[2]) - 1)
		var wy: int = int(wr2[1]) - 1
		for _s in range(rng.randi_range(6, 10)):
			if wx >= 0 and wx < W and wy >= 0 and wy < H and fg[wy][wx] != AIR and fg[wy][wx] != PLATFORM and fg[wy][wx] != 4 and fg[wy][wx] != 5 and fg[wy][wx] != 13 and fg[wy][wx] != 6:
				fg[wy][wx] = 6
				wood_count += 1
			wx += rng.randi_range(-1, 1)
			wy += rng.randi_range(-1, 1)
	# --- spawn / exit ---
	var spawn_room: Array = rooms[0]
	var exit_room: Array = rooms[rooms.size() - 1]
	var spawn := Vector2i(spawn_room[0] + spawn_room[2] / 2, spawn_room[1] + spawn_room[3] - 2)
	var exit_cell := Vector2i(exit_room[0] + exit_room[2] / 2, exit_room[1] + exit_room[3] - 2)
	# brick floor under the exit room
	for xx in range(exit_room[0], exit_room[0] + exit_room[2]):
		fg[exit_room[1] + exit_room[3] - 1][xx] = 8
	# --- Phase 14: spawn/exit floor guarantee. A corridor's vertical
	# leg can carve the spawn/exit room's floor row (it drops to a
	# lower room through the floor), leaving the player spawning over
	# a pit — no jump at spawn, no bench/lantern placement there, and
	# props (crates) fall into the hole instead of resting on the
	# floor, which breaks push/dash/slam tests at spawn. Fix in two
	# parts: SOLID under the anchor cell itself (bench/lantern
	# placement needs solid support), and a one-way PLATFORM over any
	# other hole in the room's floor row (the player and props can
	# stand on it, and the corridor below stays open — platforms are
	# flood-fill traversable, so this can never disconnect the world).
	# Validation below measures the true final topology either way.
	var _floor_guard := func() -> void:
		for pair in [[spawn_room, spawn], [exit_room, exit_cell]]:
			var rm: Array = pair[0]
			var anchor: Vector2i = pair[1]
			var fy: int = anchor.y + 1
			for fxx in range(anchor.x - 1, anchor.x + 2):
				if fxx >= 0 and fxx < W and fy >= 0 and fy < H and fg[fy][fxx] == AIR:
					fg[fy][fxx] = 3
			for fxx in range(int(rm[0]), int(rm[0]) + int(rm[2])):
				if fxx >= 0 and fxx < W and fy >= 0 and fy < H and fg[fy][fxx] == AIR:
					fg[fy][fxx] = PLATFORM
	_floor_guard.call()
	# --- validation: flood fill from spawn over air + platforms ---
	var reachable := func() -> Dictionary:
		var seen := {}
		var stack: Array = [spawn]
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			if seen.has(c) or c.x < 0 or c.x >= W or c.y < 0 or c.y >= H:
				continue
			var t: int = fg[c.y][c.x]
			if t != AIR and t != PLATFORM:
				continue
			seen[c] = true
			stack.append(Vector2i(c.x + 1, c.y)); stack.append(Vector2i(c.x - 1, c.y))
			stack.append(Vector2i(c.x, c.y + 1)); stack.append(Vector2i(c.x, c.y - 1))
		return seen
	var seen: Dictionary = reachable.call()
	var unreached: Array = []
	for r in rooms:
		var c := Vector2i(r[0] + r[2] / 2, r[1] + r[3] / 2)
		if not seen.has(c):
			unreached.append(r)
	# W6 fix: a repair corridor's vertical leg can be severed AFTER it is
	# carved — the exit room's brick floor (whole bottom row, tile 8) and
	# the floor guard's SOLID re-fill both overwrite leg cells that cross
	# the exit floor row inside the exit room's x-span (seed 91838678:
	# legs [187,66,81] and [188,67,81] both cross row 71 at x187..189;
	# room [180,76,14,10] stayed unreached through both repairs).
	# Shift the repair leg to a slot inside the target room that avoids
	# the severed spans: the exit room's whole floor row, and the spawn
	# anchor's 3 SOLID cells. No RNG is used, and this path only runs
	# when a room is unreached, so seeds that are already connected
	# (20261101, 57109915) are byte-identical.
	var _exit_floor_row: int = int(exit_room[1]) + int(exit_room[3]) - 1
	var _spawn_floor_row: int = int(spawn_room[1]) + int(spawn_room[3]) - 1
	var _ay: int = int(spawn_room[1]) + int(spawn_room[3]) / 2
	for r in unreached:  # repair: direct corridor from spawn room
		var _by: int = int(r[1]) + int(r[3]) / 2
		var _lo: int = mini(_ay, _by)
		var _hi: int = maxi(_ay, _by)
		var _blocked := func(_bx: int) -> bool:
			if _lo <= _exit_floor_row and _exit_floor_row <= _hi and _bx + 2 >= int(exit_room[0]) and _bx <= int(exit_room[0]) + int(exit_room[2]) - 1:
				return true
			if _lo <= _spawn_floor_row and _spawn_floor_row <= _hi and _bx <= spawn.x and spawn.x <= _bx + 2:
				return true
			return false
		var _bx: int = int(r[0]) + int(r[2]) / 2
		if _blocked.call(_bx):
			if not _blocked.call(int(r[0])):
				_bx = int(r[0])
			elif not _blocked.call(int(r[0]) + int(r[2]) - 3):
				_bx = int(r[0]) + int(r[2]) - 3
		var _rb: Array = [_bx - int(r[2]) / 2, r[1], r[2], r[3]]
		corridor.call(spawn_room, _rb)
	# The repair corridor can re-open the spawn floor the guard just
	# filled, so re-apply the guard, then measure the true topology.
	_floor_guard.call()
	seen = reachable.call()
	var reached := 0
	for r in rooms:
		if seen.has(Vector2i(r[0] + r[2] / 2, r[1] + r[3] / 2)):
			reached += 1
	# W6 diagnostic (scratch only): name any room still unreached
	# after repair, so a connected=false READY line is actionable.
	for r in rooms:
		var _uc := Vector2i(r[0] + r[2] / 2, r[1] + r[3] / 2)
		if not seen.has(_uc):
			print("DEEPFALL_W6_UNREACHED room=%s center=%s spawn=%s exit=%s" % [str(r), str(_uc), str(spawn), str(exit_cell)])
	# --- W3: climb ledges in every vertical corridor leg. A leg is a
	# 3-wide shaft; a single jump rises ~1.8 tiles (117 px), so a shaft
	# of 2+ rows is unclimbable without mining — the bot fell 35 rows
	# and camped the pit in every soak so far. Add stepped one-way
	# platforms one row apart (64 px rise per hop, inside a single
	# jump; a human can double-jump past every other step),
	# alternating 2-wide left/right so a 1-wide gap always stays open
	# for falling back down. Rows top+3..bot+2: the first step is one
	# row above the lower corridor floor, the last one row above the
	# upper corridor floor. Fully deterministic geometry — NO rng
	# calls, so the RNG stream for ore/coal/wood is untouched and the
	# READY line cannot move. Ledges only replace AIR (never solid or
	# ore), and flood-fill treats PLATFORM as traversable, so the
	# measured connected=true above cannot change either.
	var ledge_count := 0
	for leg in vlegs:
		var lbx: int = leg[0]
		var ltop: int = leg[1]
		var lbot: int = leg[2]
		for p in range(ltop + 3, lbot + 3):
			if p < 0 or p >= H:
				continue
			var lx0: int = lbx if (p % 2 == 0) else lbx + 1
			for ldx in range(2):
				var lxx: int = lx0 + ldx
				if lxx >= 0 and lxx < W and fg[p][lxx] == AIR:
					fg[p][lxx] = PLATFORM
					ledge_count += 1
	print("DEEPFALL_W3_LEDGES legs=%d cells=%d" % [vlegs.size(), ledge_count])
	# --- solid tile variety + wall grid (behind air only) ---
	for yy in range(H):
		for xx in range(W):
			if fg[yy][xx] == 3:
				if yy < 5:
					fg[yy][xx] = 11 if (xx * 7 + yy) % 5 == 0 else 1
				else:
					# Moss clusters, not scattered singles: the condition
					# depends on the 3x3 block, so a whole block turns
					# mossy together (topology unchanged — still solid).
					var h := (xx * 31 + yy * 17) % 20
					var bx := xx / 3; var by := yy / 3
					if (bx * 7 + by * 11 + seed) % 10 == 0: fg[yy][xx] = 9
					elif h == 1: fg[yy][xx] = 10
					elif yy > H - 10 and h == 2: fg[yy][xx] = 12
			if fg[yy][xx] == AIR or fg[yy][xx] == PLATFORM:
				# dark wall below ~55% depth (was yy > 25 on a 45-row map)
				wall[yy][xx] = 2 if yy > H * 0.56 else 1
	# grass on the topmost solid row where the cell above is air
	for yy in range(1, H):
		for xx in range(W):
			if fg[yy][xx] == 1 and fg[yy - 1][xx] == AIR:
				fg[yy][xx] = 2
	return {"fg": fg, "wall": wall, "rooms": rooms, "spawn": spawn,
		"exit": exit_cell, "ore": ore_count, "coal": coal_count, "wood": wood_count,
		"rooms_total": rooms.size(),
		"rooms_reached": reached, "connected": reached == rooms.size(), "legs": vlegs}
