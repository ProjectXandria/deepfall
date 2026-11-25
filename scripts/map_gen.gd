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
# flood-fill validated. 200x140 with 54-66 rooms (was 200x90 / 40,
# before that 80x45 / 14).
# Depth-biomes chunk (2026-11-21): H 140 -> 450, 190-210 rooms, and
# five data-driven depth bands (BIOMES below) — every band carries
# its rock material, ore, hardness and foe pressure in the table,
# so reskinning is a table edit, not a code change. The boss arena
# sits at the very bottom, centred on the spawn column, with a
# boss-rock gate and a spawn trigger (boss identity is Skit's call).
# Dig-time re-balance (same chunk, after the first measurement):
# the H=300 world measured 286 s (4.8 min) straight down — past
# Skit's 3-minute rule but under the ~10-minute bar, so H 300 -> 450
# and deep rock hardened (crystal 4->5, ember 5->6, boss 6->8 hits).
# Playtest fix wave 2: H 90 -> 140 (deeper world), and the generator
# itself got less rigid — room count, room size and loop-corridor
# count now roll per seed (was exactly 40 rooms of 8-16 x 6-10 with
# 8 loops, which made every seed feel like the same cave), and the
# ore bands jitter a few rows per seed. Room count is density-matched
# to the taller map (40 rooms on 90 rows -> ~62 on 140).
const W := 200
const H := 450
const AIR := 0
const PLATFORM := 7

# Shift I (2026-11-22): per-cell world mask, parallel to fg.
# 0 = BOTH, 1 = AMBER-only, 2 = VOID-only. Pure function of the run
# seed — assigned at the END of generate(), after the last existing
# rng draw, so no earlier draw (and no READY-line number) moves.
# Only tall-room platforms, amber-ore veins and the exit cell are
# ever gated; everything else stays BOTH by construction.
const MASK_BOTH := 0
const MASK_AMBER := 1
const MASK_VOID := 2

# New rock tile ids (main.gd FG_TO_ATLAS): 14 fungal-stone,
# 15 crystal-stone, 16 ember-stone, 17 boss-rock. Obsidian (12)
# mines at 5 hits (main.gd _hits_for_tile).
const TILE_FUNGAL := 14
const TILE_CRYSTAL := 15
const TILE_EMBER := 16
const TILE_BOSS_ROCK := 17

# Depth bands. y0 inclusive, y1 exclusive. "ore" is the precious ore
# this band's veins place (0 = none); "hard" is the mining hits for
# the band's rock (main.gd mirrors it in _hits_for_tile); "foes" is
# the per-room foe count (main.gd _build_enemy_spawn_table).
# The flat 30/75 ore bands are SUPERSEDED by this table — the old
# ore_for_band is gone; chunk8 (a) asserts against BIOMES now.
# Biome boundaries are FIXED per band (no per-seed jitter): biomes
# are structural, like regions — the old flat-band jitter went with
# the flat bands.
const BIOMES := [
	{"name": "shallows", "y0": 0, "y1": 30, "rock": 3, "ore": 0, "hard": 3, "foes": 2},
	{"name": "fungal", "y0": 30, "y1": 100, "rock": TILE_FUNGAL, "ore": 4, "hard": 3, "foes": 2},
	{"name": "crystal", "y0": 100, "y1": 230, "rock": TILE_CRYSTAL, "ore": 5, "hard": 5, "foes": 3},
	{"name": "ember", "y0": 230, "y1": 370, "rock": TILE_EMBER, "ore": 5, "hard": 6, "foes": 3},
	{"name": "boss", "y0": 370, "y1": 450, "rock": TILE_BOSS_ROCK, "ore": 5, "hard": 8, "foes": 3},
]

static func biome_index_for_y(y: int) -> int:
	for i in range(BIOMES.size()):
		if y >= int(BIOMES[i]["y0"]) and y < int(BIOMES[i]["y1"]):
			return i
	return BIOMES.size() - 1

static func biome_for_y(y: int) -> Dictionary:
	return BIOMES[biome_index_for_y(y)]

static func ore_for_biome(y: int) -> int:
	return int(biome_for_y(y)["ore"])

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
	# Playtest fix wave 2: room count / size / loop count roll per
	# seed (see the H comment above) — no two caves share the same
	# skeleton any more. Tries raised 3000 -> 6000: bigger rooms in
	# a taller world need more placement attempts.
	# Depth-biomes chunk: 190-210 rooms on 450 rows (same ~0.44
	# rooms/row density as 54-66 on 140), tries 6000 -> 18000,
	# loop corridors 6-12 -> 18-28.
	var rooms: Array = []
	var target_rooms := rng.randi_range(190, 210)
	var loop_corridors := rng.randi_range(18, 28)
	var tries := 0
	while rooms.size() < target_rooms and tries < 18000:
		tries += 1
		var rw := rng.randi_range(6, 20)
		var rh := rng.randi_range(5, 12)
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
	# Depth-biomes chunk: the spawn room is the SHALLOWEST room
	# (min y, tie-break min x) — the player always starts at the
	# surface and descends. Before this, rooms[0] (leftmost) could
	# land anywhere vertically: on seed 20261101 / H=450 the spawn
	# sat at y=306 and the straight-down dig was only 131 rows
	# (1.9 min), so the dig-time rule was meaningless per seed.
	# The spanning tree roots at the spawn room, and the arena
	# centres on its column.
	var spawn_room: Array = rooms[0]
	var spawn_idx := 0
	for ri in range(rooms.size()):
		var r: Array = rooms[ri]
		if int(r[1]) < int(spawn_room[1]) or (int(r[1]) == int(spawn_room[1]) and int(r[0]) < int(spawn_room[0])):
			spawn_room = r
			spawn_idx = ri
	# --- boss arena (depth-biomes chunk): a real arena room at the
	# very bottom, centred on the spawn column so the straight-down
	# dig from spawn ends at its gate. Interior 24x8, brick floor,
	# obsidian pillars, 3-wide entry shaft from the boss band down
	# to the gate row, gate = 3 boss-rock cells across the shaft
	# mouth. The arena is carved AFTER the rooms (it overwrites
	# them) and re-applied after the corridors (a leg can sever its
	# floor, same failure mode as the exit floor — see the W6 fix).
	# Rooms intersecting the arena/shaft are recorded in
	# arena_room_indices: no foe/trap/shop/ore spawns inside the
	# arena (main.gd + wazhack.gd honour the list). The gate is
	# SOLID by design — flood-fill "reaches" the arena when it
	# reaches the shaft cell just above the gate; the interior
	# opens only when the gate is mined (see _run_selftest_boss).
	var arena_w := 24
	var arena_h := 10
	var spawn_cx: int = int(spawn_room[0]) + int(spawn_room[2]) / 2
	var arena_x: int = clampi(spawn_cx - arena_w / 2, 2, W - arena_w - 2)
	var arena_y: int = H - arena_h - 2
	var shaft_x: int = clampi(spawn_cx - 1, 2, W - 4)
	var shaft_top: int = int(BIOMES[4]["y0"]) - 2
	var gate_y: int = arena_y - 1
	var arena_rect: Array = [arena_x, arena_y, arena_w, arena_h]
	var arena_room_indices: Array = []
	for ri in range(rooms.size()):
		var rr: Array = rooms[ri]
		var hits_arena: bool = not (int(rr[0]) > arena_x + arena_w + 1 or int(rr[0]) + int(rr[2]) < arena_x - 1 or int(rr[1]) > arena_y + arena_h + 1 or int(rr[1]) + int(rr[3]) < arena_y - 1)
		var hits_shaft: bool = not (int(rr[0]) > shaft_x + 3 + 1 or int(rr[0]) + int(rr[2]) < shaft_x - 1 or int(rr[1]) > gate_y + 1 or int(rr[1]) + int(rr[3]) < shaft_top - 1)
		if hits_arena or hits_shaft:
			arena_room_indices.append(ri)
	var boss_spawn := Vector2i(arena_x + arena_w / 2, arena_y + arena_h - 2)
	var carve_arena := func() -> void:
		for yy in range(arena_y, arena_y + arena_h - 1):  # leave floor row solid
			for xx in range(arena_x, arena_x + arena_w):
				fg[yy][xx] = AIR
		for xx in range(arena_x, arena_x + arena_w):
			fg[arena_y + arena_h - 1][xx] = 8  # brick floor
		# Obsidian pillars (cover, not blockers): 3 tall from the floor.
		for px in [arena_x + 6, arena_x + arena_w - 7]:
			for py in range(arena_y + arena_h - 4, arena_y + arena_h - 1):
				fg[py][px] = 12
		# Entry shaft: 3-wide air from the boss band down to the gate.
		for yy in range(shaft_top, gate_y):
			for dx in range(3):
				fg[yy][shaft_x + dx] = AIR
		# Gate: 3 boss-rock cells across the shaft mouth.
		for dx in range(3):
			fg[gate_y][shaft_x + dx] = TILE_BOSS_ROCK
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
	carve_arena.call()
	# --- spanning tree + 8 loop corridors ---
	var connected: Array = [spawn_room]
	for r in rooms.slice(1):
		var near: Array = connected[0]
		var best := 99999
		for o in connected:
			var d: int = abs(int(o[0]) - int(r[0])) + abs(int(o[1]) - int(r[1]))
			if d < best:
				best = d; near = o
		corridor.call(near, r)
		connected.append(r)
	for _i in range(loop_corridors):
		var a: Array = rooms[rng.randi_range(0, rooms.size() - 1)]
		var b: Array = rooms[rng.randi_range(0, rooms.size() - 1)]
		if abs(a[0] - b[0]) > 20:
			corridor.call(a, b)
	# Connect the arena shaft to the nearest room (its top is a 3x3
	# pseudo-room at the shaft mouth), then re-apply the arena: a
	# corridor leg can sever its floor/pillars/gate, same as the exit
	# floor in the W6 fix.
	var nearest: Array = rooms[0]
	var bestd := 99999
	for r in rooms:
		var d: int = abs(int(r[0]) - shaft_x) + abs(int(r[1]) - shaft_top)
		if d < bestd:
			bestd = d
			nearest = r
	corridor.call(nearest, [shaft_x - 1, shaft_top - 1, 3, 3])
	carve_arena.call()
	# --- platforms in tall rooms ---
	# (Shift I: these runs are recorded so the mask can gate ~1/3 of
	# them. The W3 climb ledges and the floor-guard platforms below
	# are NOT recorded — they are structural and stay BOTH.)
	var tall_platform_runs: Array = []
	var amber_veins: Array = []
	for r in rooms:
		if r[3] >= 8:
			var px: int = int(r[0]) + 2
			while px < r[0] + r[2] - 2:
				var py: int = int(r[1]) + 3
				if fg[py][px] == AIR and not (px >= arena_x and px < arena_x + arena_w and py >= arena_y and py < arena_y + arena_h):
					var run: Array = []
					for dx in range(3):
						if px + dx < r[0] + r[2]:
							fg[py][px + dx] = PLATFORM
							run.append(Vector2i(px + dx, py))
					if not run.is_empty():
						tall_platform_runs.append(run)
				px += 5
	# --- ore veins: connected random walks in solid cells above rooms ---
	var ore_count := 0
	for i in range(rooms.size()):
		if i == spawn_idx:
			continue  # never in spawn room
		if i in arena_room_indices:
			continue  # never inside the boss arena
		var r: Array = rooms[i]
		# Ember rooms run richer: 2-3 walks instead of 1-2.
		var walks := rng.randi_range(1, 2)
		if int(r[1]) >= int(BIOMES[3]["y0"]):
			walks = rng.randi_range(2, 3)
		for _v in range(walks):
			var vx: int = int(r[0]) + rng.randi_range(0, int(r[2]) - 1)
			var vy: int = int(r[1]) - 1
			# Shift I: the amber cells of this walk are one vein — the
			# mask splits veins half/half between the worlds. Gold
			# stays BOTH, so only amber cells are recorded.
			var vein_cells: Array = []
			for _s in range(rng.randi_range(4, 9)):
				if vx >= 0 and vx < W and vy >= 0 and vy < H and fg[vy][vx] != AIR and fg[vy][vx] != PLATFORM:
					# Depth-biomes chunk: the ore TYPE is a pure
					# function of the cell's y band (ore_for_biome):
					# none shallow, gold in Fungal, amber in
					# Crystal/Ember/Boss. Shallow cells stay stone:
					# no placement, no ore_count increment, walk
					# continues as before.
					var band_ore: int = ore_for_biome(vy)
					if band_ore != 0:
						fg[vy][vx] = band_ore
						ore_count += 1
						if band_ore == 5:
							vein_cells.append(Vector2i(vx, vy))
				vx += rng.randi_range(-1, 1)
				vy += rng.randi_range(0, 1)
			if not vein_cells.is_empty():
				amber_veins.append(vein_cells)
	# --- Phase 7: coal + wood veins (connected random walks, same shape
	# as the ore veins, AFTER them so the ore count / READY line is
	# untouched). Solid-to-solid only (never air/platform/ore), so
	# topology, flood-fill and spawn/exit are unchanged. Coal and wood
	# are the Phase 7 crafting materials: coal-ore (13) and wood (6)
	# were never generated before this phase — wood blocks in
	# particular existed as a tile id but with zero cells in the world,
	# which would have made torch crafting impossible.
	# Depth-biomes chunk: coal/wood vein counts scale with the taller
	# world (20/26 on 140 rows -> 66/84 on 450), and veins never
	# start in an arena room.
	var _pick_vein_room := func() -> Array:
		for _t in range(8):
			var _idx := rng.randi_range(0, rooms.size() - 1)
			if _idx != spawn_idx and not (_idx in arena_room_indices):
				return rooms[_idx]
		return rooms[1] if spawn_idx != 1 else rooms[2]
	var coal_count := 0
	for _cv in range(66):
		var cr: Array = _pick_vein_room.call()
		var cx: int = int(cr[0]) + rng.randi_range(0, int(cr[2]) - 1)
		var cy: int = int(cr[1]) - 1
		for _s in range(rng.randi_range(4, 7)):
			if cx >= 0 and cx < W and cy >= 0 and cy < H and fg[cy][cx] != AIR and fg[cy][cx] != PLATFORM and fg[cy][cx] != 4 and fg[cy][cx] != 5 and fg[cy][cx] != 13:
				fg[cy][cx] = 13
				coal_count += 1
			cx += rng.randi_range(-1, 1)
			cy += rng.randi_range(-1, 1)
	var wood_count := 0
	for _wv in range(84):
		var wr2: Array = _pick_vein_room.call()
		var wx: int = int(wr2[0]) + rng.randi_range(0, int(wr2[2]) - 1)
		var wy: int = int(wr2[1]) - 1
		for _s in range(rng.randi_range(6, 10)):
			if wx >= 0 and wx < W and wy >= 0 and wy < H and fg[wy][wx] != AIR and fg[wy][wx] != PLATFORM and fg[wy][wx] != 4 and fg[wy][wx] != 5 and fg[wy][wx] != 13 and fg[wy][wx] != 6:
				fg[wy][wx] = 6
				wood_count += 1
			wx += rng.randi_range(-1, 1)
			wy += rng.randi_range(-1, 1)
	# --- spawn / exit ---
	# spawn_room is the shallowest room (picked after the sort,
	# above); exit_room is the rightmost.
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
	var _arena_floor_row: int = arena_y + arena_h - 1
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
			# Depth-biomes chunk: same rule for the arena floor row.
			if _lo <= _arena_floor_row and _arena_floor_row <= _hi and _bx + 2 >= arena_x and _bx <= arena_x + arena_w - 1:
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
	# Depth-biomes chunk: the arena counts as reached when flood-fill
	# gets to the shaft cell just above the gate — the gate itself is
	# solid by design, so the interior is never flood-reachable. If
	# the shaft is cut off, repair it with a direct corridor from the
	# spawn room to the shaft top, then re-apply the arena (the leg
	# can carve through the gate row) and re-measure.
	var arena_mouth := Vector2i(shaft_x + 1, gate_y - 1)
	var arena_reached: bool = seen.has(arena_mouth)
	if not arena_reached:
		corridor.call(spawn_room, [shaft_x - 1, shaft_top - 1, 3, 3])
		carve_arena.call()
		_floor_guard.call()
		seen = reachable.call()
		arena_reached = seen.has(arena_mouth)
		reached = 0
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
					# Depth-biomes chunk: the base rock is the biome's
					# material (BIOMES rock), hash-picked per cell so
					# a band reads as one family with variation.
					# Moss clusters, not scattered singles: the
					# condition depends on the 3x3 block, so a whole
					# block turns mossy together (topology unchanged
					# — still solid).
					var h := (xx * 31 + yy * 17) % 20
					var bx := xx / 3; var by := yy / 3
					var brock: int = int(biome_for_y(yy)["rock"])
					if brock == 3:
						# Shallows keep the old behaviour.
						if (bx * 7 + by * 11 + seed) % 10 == 0: fg[yy][xx] = 9
						elif h == 1: fg[yy][xx] = 10
						elif yy > H - 10 and h == 2: fg[yy][xx] = 12
					elif brock == TILE_FUNGAL:
						if (bx * 7 + by * 11 + seed) % 10 == 0: fg[yy][xx] = 9
						elif h < 12: fg[yy][xx] = TILE_FUNGAL
						elif h == 12: fg[yy][xx] = 10
					elif brock == TILE_CRYSTAL:
						if h < 14: fg[yy][xx] = TILE_CRYSTAL
						elif h == 14: fg[yy][xx] = 9
					elif brock == TILE_EMBER:
						if h < 11: fg[yy][xx] = TILE_EMBER
						elif h < 16: fg[yy][xx] = 12
						elif h == 16: fg[yy][xx] = 10
					else:  # boss band: solid boss-rock
						fg[yy][xx] = TILE_BOSS_ROCK
			if fg[yy][xx] == AIR or fg[yy][xx] == PLATFORM:
				# dark wall below ~55% depth (was yy > 25 on a 45-row map)
				wall[yy][xx] = 2 if yy > H * 0.56 else 1
	# grass on the topmost solid row where the cell above is air
	for yy in range(1, H):
		for xx in range(W):
			if fg[yy][xx] == 1 and fg[yy - 1][xx] == AIR:
				fg[yy][xx] = 2
	# --- Shift I: world mask (LAST draw — after the grass pass, so no
	# earlier draw moves and the same seed still yields the same cave.
	# The mask is a pure function of the run seed: re-derived on load,
	# never stored in the save.) ---
	# ~1/3 of tall-room platform runs gated, half of those AMBER-only,
	# half VOID-only; amber-ore veins split half/half per vein; the
	# exit cell is VOID-only. Everything else stays BOTH.
	var world_mask: Array = []
	for _y in range(H):
		var mrow: Array = []
		mrow.resize(W)
		mrow.fill(MASK_BOTH)
		world_mask.append(mrow)
	for run in tall_platform_runs:
		if rng.randi_range(0, 2) == 0:
			var w: int = MASK_AMBER if rng.randi_range(0, 1) == 0 else MASK_VOID
			for c in run:
				# Only gate the cell if it is still a platform — a
				# later draw may have overwritten it (room carve,
				# arena); gating the replacement tile would be wrong.
				if fg[c.y][c.x] == 7:
					world_mask[c.y][c.x] = w
	for vein in amber_veins:
		var w2: int = MASK_AMBER if rng.randi_range(0, 1) == 0 else MASK_VOID
		for c in vein:
			# Same guard: only gate surviving amber-ore cells.
			if fg[c.y][c.x] == 5:
				world_mask[c.y][c.x] = w2
	world_mask[exit_cell.y][exit_cell.x] = MASK_VOID
	return {"fg": fg, "wall": wall, "rooms": rooms, "spawn": spawn,
		"exit": exit_cell, "ore": ore_count, "coal": coal_count, "wood": wood_count,
		"rooms_total": rooms.size(),
		"rooms_reached": reached, "connected": reached == rooms.size(), "legs": vlegs,
		"boss_arena": {"rect": arena_rect, "gate_y": gate_y, "shaft_x": shaft_x,
			"shaft_top": shaft_top, "spawn_cell": boss_spawn,
			"room_indices": arena_room_indices},
		"arena_reached": arena_reached, "world_mask": world_mask}
