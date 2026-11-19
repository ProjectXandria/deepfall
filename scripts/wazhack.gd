# wazhack.gd — DEEPFALL WazHack systems wave (systems 1-8).
# Pure rules + run state for hunger, identification, traps, shops,
# talents, pets, polymorph and rumours. main.gd owns the world, the
# HUD and the save file; this module owns the WazHack rules and is
# called from main.gd hooks. Deterministic per run_seed: placement
# rolls use a dedicated RNG (seed run_seed * 1000003 + 77) so the
# map_gen stream is never disturbed.
class_name DeepfallWazhack
extends RefCounted

const HUNGER_MAX := 100.0
const TILE := 64 # same as main.gd's TILE (map_gen has no TILE const)
const HUNGER_DRAIN := 0.2 # 100 -> 0 in 500 s of run time
const HUNGER_HUNGRY := 35.0
const HUNGER_STARVING := 15.0
const HUNGER_SATIATED := 80.0
const BURDEN_LIMIT := 80
const BURDEN_MULT := 0.75
const KILLS_PER_LEVEL := 8
const PET_SENSE_TILES := 4
const POLY_SECONDS := 20.0

const FOOD := {
	"meat": 25, "cooked_meat": 55, "bread": 35,
	"mushroom": 15, "mushroom_stew": 40, "royal_jelly": 100,
}
const FOOD_NAMES := {
	"meat": "Raw Meat", "cooked_meat": "Cooked Meat", "bread": "Bread",
	"mushroom": "Mushroom", "mushroom_stew": "Mushroom Stew", "royal_jelly": "Royal Jelly",
}
const POTION_APPS := ["cloudy", "swirly", "bubbly", "murky", "blue", "black"]
const POTION_FX := ["healing", "speed", "polymorph", "sickness", "enlightenment", "invisibility"]
const POTION_FX_NAMES := {
	"healing": "Healing", "speed": "Speed", "polymorph": "Polymorph",
	"sickness": "Sickness", "enlightenment": "Enlightenment", "invisibility": "Invisibility",
}
const WAND_MATS := ["crooked", "ebony", "glass", "forked"]
const WAND_FX := ["fire", "polymorph", "teleportation", "probing"]
const WAND_FX_NAMES := {
	"fire": "Fire", "polymorph": "Polymorph",
	"teleportation": "Teleportation", "probing": "Probing",
}
const RING_GEMS := ["agate", "twisted", "onyx", "tigereye"]
const RING_FX := ["regeneration", "gain_strength", "slow_digestion", "see_invisible"]
const RING_FX_NAMES := {
	"regeneration": "Regeneration", "gain_strength": "Gain Strength",
	"slow_digestion": "Slow Digestion", "see_invisible": "See Invisible",
}
const SCROLL_KINDS := ["identify", "remove_curse", "magic_mapping", "taming"]
const SCROLL_NAMES := {
	"identify": "Identify", "remove_curse": "Remove Curse",
	"magic_mapping": "Magic Mapping", "taming": "Taming",
}
const TALENTS := ["literacy", "gastronomy", "trap_detection", "commerce", "mycology"]
const TALENT_NAMES := {
	"literacy": "Literacy", "gastronomy": "Gastronomy",
	"trap_detection": "Trap Detection", "commerce": "Commerce", "mycology": "Mycology",
}
const TALENT_DESCS := {
	"literacy": "Potions, wands and rings are identified on pickup. Identify scrolls identify everything you carry.",
	"gastronomy": "Food restores 50% more hunger.",
	"trap_detection": "Every trap in the cave is revealed at once.",
	"commerce": "Shop prices -20%, selling +20%.",
	"mycology": "Mushrooms restore 25 hunger and heal 5 HP.",
}
const POLY_FORMS := {
	"bat": {"melee": 0.5, "speed": 1.4, "tint": Color(0.6, 0.8, 1.0), "label": "BAT"},
	"spider": {"melee": 1.0, "speed": 1.2, "tint": Color(0.6, 1.0, 0.6), "label": "SPIDER"},
	"golem": {"melee": 1.5, "speed": 0.6, "tint": Color(0.75, 0.75, 0.8), "label": "GOLEM"},
}
const TRAP_KINDS := ["teleport", "sleep", "polymorph"]
const RUMOUR_FALLBACK := [
	"t|The caves get hungrier the deeper you go. Eat before you starve.",
	"t|A cloudy potion once saved a miner. Or so the saying goes.",
	"f|Bats never drop anything. Do not bother with them.",
	"u|The amber down here hums when nobody is listening.",
	"t|A dog pup will follow a kind hand. Bring meat.",
	"f|Fountains are always safe. Drink deep.",
]

var main = null
var inv: Dictionary = {}
var seed: int = 0
var rng: RandomNumberGenerator = null

# --- run state ---
var hunger: float = HUNGER_MAX
var identified: Dictionary = {}
var bless: Dictionary = {}
var known: Dictionary = {}
var talents: Dictionary = {}
var level: int = 0
var talent_choices: Array = []
var traps: Array = []
var shops: Array = []
var pet_tamed: bool = false
var pet_alive: bool = true
var pet_hp: int = 30
var pet_den_cell := Vector2i(-1, -1)
var worn_ring: String = ""
var poly_active: bool = false
var poly_form: String = ""
var poly_left: float = 0.0
var poly_base_melee: int = 15
var poly_base_speed: float = 1.0
var poly_boost: bool = false
var control_ring_dropped: bool = false
var speed_left: float = 0.0
var speed_base: float = 1.0
var speed_slow: bool = false
var invis_left: float = 0.0
var sleep_left: float = 0.0
var hungry_warned: bool = false
var starving_warned: bool = false
var starve_timer: float = 0.0
var satiated_timer: float = 0.0
var regen_timer: float = 0.0
var rumours: Array = []
var visited_features: Dictionary = {}
var _restored: bool = false
var _rooms: Array = []

func setup(p_main, p_inv: Dictionary, p_seed: int) -> void:
	main = p_main
	inv = p_inv
	seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = seed * 1000003 + 77
	_load_rumours()
	_roll_identification()

func _roll_identification() -> void:
	identified.clear()
	bless.clear()
	known.clear()
	var pe := POTION_FX.duplicate()
	_shuffle(pe)
	for i in range(POTION_APPS.size()):
		identified["potion_" + POTION_APPS[i]] = pe[i]
	var we := WAND_FX.duplicate()
	_shuffle(we)
	for i in range(WAND_MATS.size()):
		identified["wand_" + WAND_MATS[i]] = we[i]
	var re := RING_FX.duplicate()
	_shuffle(re)
	for i in range(RING_GEMS.size()):
		identified["ring_" + RING_GEMS[i]] = re[i]
	for key in identified.keys():
		var r := rng.randf()
		bless[key] = 1 if r < 0.15 else (-1 if r < 0.30 else 0)
		known[key] = false

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _load_rumours() -> void:
	rumours.clear()
	var path := "res://data/rumours.txt"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			for line in f.get_as_text().split("\n"):
				line = line.strip_edges()
				if line == "" or line.begins_with("#"):
					continue
				rumours.append(line)
			f.close()
	if rumours.is_empty():
		rumours = RUMOUR_FALLBACK.duplicate()

func rumour() -> String:
	if rumours.is_empty():
		return ""
	return String(rumours[rng.randi_range(0, rumours.size() - 1)])

func rumour_counts() -> Dictionary:
	var c := {"t": 0, "f": 0, "u": 0}
	for r in rumours:
		var tag := String(r).substr(0, 1)
		if c.has(tag):
			c[tag] = int(c[tag]) + 1
	return c

# --- world build: fresh roll, or restore from save ---

func on_world_built(rooms: Array) -> void:
	_rooms = rooms
	if _restored:
		_restored = false
		return
	new_run(rooms)

func new_run(rooms: Array) -> void:
	_rooms = rooms
	rng.seed = seed * 1000003 + 77
	_roll_identification()
	hunger = HUNGER_MAX
	talents.clear()
	for t in TALENTS:
		talents[t] = false
	level = 0
	talent_choices.clear()
	traps.clear()
	shops.clear()
	pet_tamed = false
	pet_alive = true
	pet_hp = 30
	worn_ring = ""
	poly_active = false
	poly_form = ""
	poly_left = 0.0
	poly_boost = false
	control_ring_dropped = false
	speed_left = 0.0
	speed_slow = false
	invis_left = 0.0
	sleep_left = 0.0
	hungry_warned = false
	starving_warned = false
	starve_timer = 0.0
	satiated_timer = 0.0
	regen_timer = 0.0
	visited_features.clear()
	_roll_traps(rooms)
	_roll_shops(rooms)
	var taken: Array = []
	for t in traps:
		taken.append(t["cell"])
	for s in shops:
		taken.append(s["cell"])
	pet_den_cell = _room_floor_cell(rooms, _pick_room(rooms), taken)

func _pick_room(rooms: Array) -> int:
	if rooms.size() <= 2:
		return 0
	return rng.randi_range(1, rooms.size() - 2)

func _room_floor_cell(rooms: Array, idx: int, avoid: Array = []) -> Vector2i:
	if idx < 0 or idx >= rooms.size():
		return Vector2i(-1, -1)
	var r: Array = rooms[idx]
	for _try in range(8):
		var cx := rng.randi_range(int(r[0]) + 1, int(r[0]) + int(r[2]) - 2)
		# map_gen carves rooms leaving the bottom row SOLID (the
		# floor); the standing cell is the row above it (ry+rh-2,
		# same as the spawn/exit cells). The old rh-1 read the
		# solid floor row, so only corridor-cut cells validated.
		var cy := int(r[1]) + int(r[3]) - 2
		var cell := Vector2i(cx, cy)
		if cell in avoid:
			continue
		if _is_floor_cell(cx, cy):
			return cell
	return Vector2i(-1, -1)

func _is_floor_cell(cx: int, cy: int) -> bool:
	if main == null:
		return false
	var fg: Array = main.fg
	if cy < 0 or cy + 1 >= DeepfallMapGen.H or cx < 0 or cx >= DeepfallMapGen.W:
		return false
	if int(fg[cy][cx]) != 0:
		return false
	var below: int = int(fg[cy + 1][cx])
	return below != 0

func _roll_traps(rooms: Array) -> void:
	var count: int = rooms.size() / 3
	var idxs: Array = []
	for i in range(1, rooms.size() - 1):
		idxs.append(i)
	_shuffle(idxs)
	for n in range(mini(count, idxs.size())):
		var cell := _room_floor_cell(rooms, int(idxs[n]))
		if cell.x < 0:
			continue
		traps.append({"cell": cell, "kind": TRAP_KINDS[rng.randi_range(0, 2)],
			"revealed": false, "sprung": false})

func _roll_shops(rooms: Array) -> void:
	var idxs: Array = []
	for i in range(1, rooms.size() - 1):
		idxs.append(i)
	_shuffle(idxs)
	if idxs.size() < 3:
		return
	var kinds := ["forge", "bakery", "altar" if rng.randf() < 0.5 else "fountain"]
	# shops never share a cell with a trap — the keeper's own floor
	# must be safe to stand on.
	var avoid: Array = []
	for t in traps:
		avoid.append(t["cell"])
	for n in range(3):
		var cell := _room_floor_cell(rooms, int(idxs[n]), avoid)
		if cell.x < 0:
			continue
		shops.append({"kind": kinds[n], "room": int(idxs[n]), "cell": cell})
		avoid.append(cell)

# --- save / load (additive optional "wazhack" field; SAVE_VERSION stays 9) ---

func to_save() -> Dictionary:
	var trap_list: Array = []
	for t in traps:
		var c: Vector2i = t["cell"]
		trap_list.append({"cell": "%d,%d" % [c.x, c.y], "kind": String(t["kind"]),
			"revealed": bool(t["revealed"]), "sprung": bool(t["sprung"])})
	var shop_list: Array = []
	for s in shops:
		var c2: Vector2i = s["cell"]
		shop_list.append({"kind": String(s["kind"]), "room": int(s["room"]),
			"cell": "%d,%d" % [c2.x, c2.y]})
	return {"hunger": hunger, "identified": identified.duplicate(),
		"bless": bless.duplicate(), "known": known.duplicate(),
		"talents": talents.duplicate(), "level": level,
		"talent_choices": talent_choices.duplicate(),
		"traps": trap_list, "shops": shop_list,
		"pet_tamed": pet_tamed, "pet_alive": pet_alive, "pet_hp": pet_hp,
		"pet_den_cell": "%d,%d" % [pet_den_cell.x, pet_den_cell.y],
		"worn_ring": worn_ring, "poly_active": poly_active,
		"poly_form": poly_form, "poly_left": poly_left,
		"poly_base_melee": poly_base_melee, "poly_base_speed": poly_base_speed,
		"poly_boost": poly_boost,
		"control_ring_dropped": control_ring_dropped,
		"speed_left": speed_left, "speed_slow": speed_slow,
		"invis_left": invis_left, "sleep_left": sleep_left,
		"hungry_warned": hungry_warned, "starving_warned": starving_warned}

func from_save(d: Dictionary) -> void:
	if d.is_empty():
		return
	hunger = float(d.get("hunger", HUNGER_MAX))
	identified = (d.get("identified", {}) as Dictionary).duplicate()
	bless = (d.get("bless", {}) as Dictionary).duplicate()
	known = (d.get("known", {}) as Dictionary).duplicate()
	talents = (d.get("talents", {}) as Dictionary).duplicate()
	for t in TALENTS:
		if not talents.has(t):
			talents[t] = false
	level = int(d.get("level", 0))
	talent_choices = (d.get("talent_choices", []) as Array).duplicate()
	traps.clear()
	for t in (d.get("traps", []) as Array):
		var p: PackedStringArray = String(t.get("cell", "-1,-1")).split(",")
		traps.append({"cell": Vector2i(int(p[0]), int(p[1])), "kind": String(t.get("kind", "teleport")),
			"revealed": bool(t.get("revealed", false)), "sprung": bool(t.get("sprung", false))})
	shops.clear()
	for s in (d.get("shops", []) as Array):
		var p2: PackedStringArray = String(s.get("cell", "-1,-1")).split(",")
		shops.append({"kind": String(s.get("kind", "forge")), "room": int(s.get("room", 1)),
			"cell": Vector2i(int(p2[0]), int(p2[1]))})
	pet_tamed = bool(d.get("pet_tamed", false))
	pet_alive = bool(d.get("pet_alive", true))
	pet_hp = int(d.get("pet_hp", 30))
	var pd: PackedStringArray = String(d.get("pet_den_cell", "-1,-1")).split(",")
	pet_den_cell = Vector2i(int(pd[0]), int(pd[1]))
	worn_ring = String(d.get("worn_ring", ""))
	poly_active = bool(d.get("poly_active", false))
	poly_form = String(d.get("poly_form", ""))
	poly_left = float(d.get("poly_left", 0.0))
	poly_base_melee = int(d.get("poly_base_melee", 15))
	poly_base_speed = float(d.get("poly_base_speed", 1.0))
	poly_boost = bool(d.get("poly_boost", false))
	control_ring_dropped = bool(d.get("control_ring_dropped", false))
	speed_left = float(d.get("speed_left", 0.0))
	speed_slow = bool(d.get("speed_slow", false))
	invis_left = float(d.get("invis_left", 0.0))
	sleep_left = float(d.get("sleep_left", 0.0))
	hungry_warned = bool(d.get("hungry_warned", false))
	starving_warned = bool(d.get("starving_warned", false))
	_restored = true

# --- hunger ---

func burden_mult() -> float:
	var total := 0
	for k in inv.keys():
		total += int(inv[k])
	return BURDEN_MULT if total > BURDEN_LIMIT else 1.0

func tick(delta: float) -> void:
	if main == null or main.player == null:
		return
	var pl = main.player
	if bool(pl.get("dead")):
		return
	var drain := HUNGER_DRAIN
	if worn_ring != "" and String(identified.get(worn_ring, "")) == "slow_digestion":
		drain *= 0.5
	if worn_ring != "" and String(identified.get(worn_ring, "")) == "regeneration" and int(bless.get(worn_ring, 0)) == -1:
		drain *= 2.0 # cursed regeneration ring: it heals you, but eats twice as fast
	hunger = maxf(0.0, hunger - drain * delta)
	if hunger < HUNGER_HUNGRY and not hungry_warned:
		hungry_warned = true
		_log("You feel hungry.")
	if hunger >= HUNGER_HUNGRY:
		hungry_warned = false
	if hunger < HUNGER_STARVING and not starving_warned:
		starving_warned = true
		_log("You are starving!")
	if hunger >= HUNGER_STARVING:
		starving_warned = false
		starve_timer = 0.0
	if hunger < HUNGER_STARVING:
		starve_timer += delta
		if starve_timer >= 3.0:
			starve_timer = 0.0
			_hurt_player(1)
			_log("Starvation gnaws at you.")
	else:
		starve_timer = 0.0
	if hunger > HUNGER_SATIATED:
		satiated_timer += delta
		if satiated_timer >= 8.0:
			satiated_timer = 0.0
			_heal_player(1)
	else:
		satiated_timer = 0.0
	if worn_ring != "" and String(identified.get(worn_ring, "")) == "regeneration":
		regen_timer += delta
		if regen_timer >= 5.0:
			regen_timer = 0.0
			_heal_player(1)
	else:
		regen_timer = 0.0
	if speed_left > 0.0:
		speed_left -= delta
		if speed_left <= 0.0:
			pl.speed_mult = speed_base
			_log("The speed fades.")
	if invis_left > 0.0:
		invis_left -= delta
	if sleep_left > 0.0:
		sleep_left -= delta
		if sleep_left <= 0.0:
			pl.sleeping = false
			_log("You wake up.")
	if poly_active:
		poly_left -= delta
		if poly_left <= 0.0:
			_end_poly()
	# pet + see-invisible ring sense hidden traps nearby
	if pet_tamed and pet_alive and main.get("pet") != null:
		var pet = main.pet
		if pet != null:
			reveal_traps_near(pet.cell(), PET_SENSE_TILES)
	if worn_ring != "" and String(identified.get(worn_ring, "")) == "see_invisible":
		reveal_traps_near(pl.cell(), 6)

func _hurt_player(n: int) -> void:
	var pl = main.player
	pl.hp = maxi(0, int(pl.hp) - n)
	if int(pl.hp) <= 0:
		pl.hurt_timer = 0.0
		pl.take_hit(1, pl.position.x)

func _heal_player(n: int) -> void:
	var pl = main.player
	pl.hp = mini(int(pl.max_hp), int(pl.hp) + n)

func _log(msg: String) -> void:
	if main != null and main.has_method("log_event"):
		main.call("log_event", msg)

# --- food / consumables ---

func eat(item: String) -> bool:
	if int(inv.get(item, 0)) <= 0:
		return false
	var val: int = int(FOOD.get(item, 0))
	if item == "mushroom" and bool(talents.get("mycology", false)):
		val = 25
		_heal_player(5)
	elif bool(talents.get("gastronomy", false)):
		val = int(round(float(val) * 1.5))
	inv[item] = int(inv[item]) - 1
	hunger = minf(HUNGER_MAX, hunger + float(val))
	_log("You eat the %s. (+%d hunger)" % [String(FOOD_NAMES.get(item, item)), val])
	return true

func use_item(item: String) -> bool:
	if item.begins_with("potion_"):
		return use_potion(String(item.trim_prefix("potion_")))
	if item.begins_with("wand_"):
		return use_wand(String(item.trim_prefix("wand_")))
	if item.begins_with("ring_"):
		if item == "ring_control":
			return use_control_ring()
		return use_ring(String(item.trim_prefix("ring_")))
	if item.begins_with("scroll_"):
		return use_scroll(String(item.trim_prefix("scroll_")))
	if FOOD.has(item):
		return eat(item)
	return false

func _bless_mult(key: String) -> float:
	return 2.0 if int(bless.get(key, 0)) == 1 else 1.0

func _is_cursed(key: String) -> bool:
	return int(bless.get(key, 0)) == -1

func _reveal_on_use(key: String, label: String) -> String:
	if not bool(known.get(key, false)):
		known[key] = true
		return " It was %s!" % label
	return ""

func use_potion(app: String) -> bool:
	var key := "potion_" + app
	if int(inv.get(key, 0)) <= 0:
		return false
	var fx: String = String(identified.get(key, "healing"))
	var label := "Potion of " + String(POTION_FX_NAMES.get(fx, fx))
	inv[key] = int(inv[key]) - 1
	var extra := _reveal_on_use(key, label)
	var blessed := int(bless.get(key, 0)) == 1
	var cursed := _is_cursed(key)
	match fx:
		"healing":
			if cursed:
				_hurt_player(20)
				_log("You quaff the %s potion. It burns going down! (-20 HP)%s" % [app, extra])
			else:
				_heal_player(int(30.0 * _bless_mult(key)))
				_log("You quaff the %s potion. Warmth spreads through you. (+%d HP)%s" % [app, int(30.0 * _bless_mult(key)), extra])
		"speed":
			speed_base = float(main.player.speed_mult)
			speed_slow = cursed
			main.player.speed_mult = speed_base * (0.7 if cursed else 1.4)
			speed_left = 20.0 if blessed else 10.0
			_log("You quaff the %s potion. The world %s.%s" % [app, "drags" if cursed else "quickens", extra])
		"polymorph":
			_self_poly(_random_form(), POLY_SECONDS * (2.0 if blessed else 1.0))
			_log("You quaff the %s potion. Your body twists!%s" % [app, extra])
		"sickness":
			if blessed:
				hunger = maxf(0.0, hunger - 5.0)
				_log("You quaff the %s potion. Blessed — the sickness passes quickly.%s" % [app, extra])
			elif cursed:
				_hurt_player(20)
				hunger = maxf(0.0, hunger - 30.0)
				_log("You quaff the %s potion. Your gut revolts! (-20 HP, -30 hunger)%s" % [app, extra])
			else:
				_hurt_player(10)
				hunger = maxf(0.0, hunger - 20.0)
				_log("You quaff the %s potion. You feel ill. (-10 HP, -20 hunger)%s" % [app, extra])
		"enlightenment":
			for k in identified.keys():
				if int(inv.get(k, 0)) > 0:
					known[k] = true
			_log("You quaff the %s potion. Every item you carry suddenly makes sense.%s" % [app, extra])
		"invisibility":
			invis_left = 30.0 if blessed else (5.0 if cursed else 15.0)
			_log("You quaff the %s potion. You fade from sight.%s" % [app, extra])
	return true

func use_wand(mat: String) -> bool:
	var key := "wand_" + mat
	if int(inv.get(key, 0)) <= 0:
		return false
	var fx: String = String(identified.get(key, "fire"))
	var label := "Wand of " + String(WAND_FX_NAMES.get(fx, fx))
	inv[key] = int(inv[key]) - 1
	var extra := _reveal_on_use(key, label)
	var blessed := int(bless.get(key, 0)) == 1
	var cursed := _is_cursed(key)
	match fx:
		"fire":
			var foe = _nearest_foe(200.0)
			if foe == null:
				_log("You wave the %s wand. It fizzles — no target.%s" % [mat, extra])
			else:
				foe.take_hit(40 if blessed else (15 if cursed else 25), main.player.position.x)
				if main.fx != null:
					main.fx.burst(foe.position, Color(1.0, 0.5, 0.15), 14, 380.0)
				_log("You wave the %s wand. Fire!%s" % [mat, extra])
		"polymorph":
			var foe2 = _nearest_foe(160.0)
			if foe2 == null:
				_log("You wave the %s wand. Nothing close enough to twist.%s" % [mat, extra])
			else:
				var cell: Vector2i = foe2.cell()
				foe2.take_hit(999, main.player.position.x)
				main.call("_spawn_one", "cave-bat-swarm", cell, -1)
				_log("You wave the %s wand. The %s twists into a bat!%s" % [mat, String(foe2.slug), extra])
		"teleportation":
			_teleport_player()
			_log("You wave the %s wand. The cave rearranges around you.%s" % [mat, extra])
		"probing":
			var room: int = room_index(main.player.cell())
			var n := 0
			for t in traps:
				if not bool(t["sprung"]) and room_index(t["cell"]) == room:
					t["revealed"] = true
					n += 1
			_log("You wave the %s wand. %d trap(s) hum in this room.%s" % [mat, n, extra])
	return true

func use_ring(gem: String) -> bool:
	var key := "ring_" + gem
	if int(inv.get(key, 0)) <= 0:
		return false
	if poly_active:
		_log("You cannot change rings while polymorphed.")
		return false
	var fx: String = String(identified.get(key, "regeneration"))
	var label := "Ring of " + String(RING_FX_NAMES.get(fx, fx))
	var extra := _reveal_on_use(key, label)
	if worn_ring == key:
		_unwear_ring()
		_log("You take off the %s. (%s)%s" % [gem, label, extra])
		return true
	if worn_ring != "":
		_unwear_ring()
	worn_ring = key
	if fx == "gain_strength":
		main.player.melee_dmg += 5
	_log("You slip on the %s. (%s)%s" % [gem, label, extra])
	return true

func _unwear_ring() -> void:
	if worn_ring == "":
		return
	if String(identified.get(worn_ring, "")) == "gain_strength":
		main.player.melee_dmg = maxi(1, int(main.player.melee_dmg) - 5)
	worn_ring = ""

func use_control_ring() -> bool:
	if int(inv.get("ring_control", 0)) <= 0:
		return false
	if poly_active:
		_end_poly()
		_log("The control ring steadies you — you shift back.")
	else:
		poly_boost = true
		_log("The control ring hums. Your next shift will last twice as long.")
	return true

func use_scroll(kind: String) -> bool:
	var key := "scroll_" + kind
	if int(inv.get(key, 0)) <= 0:
		return false
	if kind == "taming" and not _can_tame():
		_log("Nothing close enough to tame.")
		return false
	inv[key] = int(inv[key]) - 1
	match kind:
		"identify":
			if bool(talents.get("literacy", false)):
				for k in identified.keys():
					if int(inv.get(k, 0)) > 0:
						known[k] = true
				_log("You read the Scroll of Identify. Everything you carry is known.")
			else:
				var done := false
				for k in identified.keys():
					if int(inv.get(k, 0)) > 0 and not bool(known.get(k, false)):
						known[k] = true
						_log("You read the Scroll of Identify. The %s is %s." % [display_name(k), String(identified[k])])
						done = true
						break
				if not done:
					_log("You read the Scroll of Identify. Nothing here is unknown.")
		"remove_curse":
			var n := 0
			for k in bless.keys():
				if int(bless[k]) == -1 and int(inv.get(k, 0)) > 0:
					bless[k] = 0
					n += 1
			_log("You read the Scroll of Remove Curse. %d item(s) cleansed." % n)
		"magic_mapping":
			reveal_all_traps()
			var pc: Vector2i = main.player.cell()
			var ex: Vector2i = main.data["exit"]
			var dir := "east" if ex.x > pc.x else "west"
			_log("You read the Scroll of Magic Mapping. Every trap is laid bare. The exit lies %s, deep down." % dir)
		"taming":
			_tame_nearest_foe()
	return true

func _can_tame() -> bool:
	if pet_tamed:
		return false
	return _nearest_foe(240.0) != null

func _tame_nearest_foe() -> void:
	var foe = _nearest_foe(240.0)
	if foe == null:
		return
	var cell: Vector2i = foe.cell()
	foe.take_hit(999, main.player.position.x)
	pet_tamed = true
	pet_alive = true
	pet_hp = 30
	pet_den_cell = cell
	_log("The scroll's words settle over the %s. It trots to your side, tamed." % String(foe.slug))
	if main != null and main.has_method("_wz_spawn_pet"):
		main.call("_wz_spawn_pet")

func _nearest_foe(max_dist: float):
	if main == null:
		return null
	var best = null
	var best_d := max_dist
	for e in main.enemies:
		if not is_instance_valid(e) or bool(e.get("dead")):
			continue
		var d: float = (e.position - main.player.position).length()
		if d < best_d:
			best_d = d
			best = e
	return best

# --- polymorph ---

func _random_form() -> String:
	var keys: Array = POLY_FORMS.keys()
	return String(keys[rng.randi_range(0, keys.size() - 1)])

func _self_poly(form: String, seconds: float) -> void:
	if poly_active:
		_end_poly()
	var pl = main.player
	poly_active = true
	poly_form = form
	poly_left = seconds * (2.0 if poly_boost else 1.0)
	poly_boost = false
	var mods: Dictionary = POLY_FORMS[form]
	# store exact bases: melee mods round (15 * 0.5 = 7.5 -> 8), so
	# dividing back would not restore the original (8 / 0.5 = 16).
	poly_base_melee = int(pl.melee_dmg)
	poly_base_speed = float(pl.speed_mult)
	pl.melee_dmg = int(round(float(pl.melee_dmg) * float(mods["melee"])))
	pl.speed_mult = float(pl.speed_mult) * float(mods["speed"])
	pl.modulate = mods["tint"]
	_log("You are a %s now. (%ss)" % [String(mods["label"]), int(poly_left)])

func _end_poly() -> void:
	if not poly_active:
		return
	var pl = main.player
	pl.melee_dmg = poly_base_melee
	pl.speed_mult = poly_base_speed
	pl.modulate = Color(1, 1, 1, 1)
	poly_active = false
	poly_form = ""
	poly_left = 0.0
	_log("You shift back to yourself.")

func _teleport_player() -> void:
	if _rooms.is_empty():
		return
	var cell := _room_floor_cell(_rooms, _pick_room(_rooms))
	if cell.x < 0:
		return
	main.player.position = Vector2((cell.x + 0.5) * TILE, (cell.y + 0.5) * TILE)
	main.player.vel = Vector2.ZERO

# --- traps ---

func check_traps(cell: Vector2i) -> bool:
	for t in traps:
		if bool(t["sprung"]):
			continue
		if t["cell"] == cell:
			t["sprung"] = true
			t["revealed"] = true
			_trigger_trap(String(t["kind"]))
			return true
	return false

func _trigger_trap(kind: String) -> void:
	match kind:
		"teleport":
			_teleport_player()
			_log("A hidden trap! You teleport!")
		"sleep":
			main.player.sleeping = true
			sleep_left = 3.0
			_log("A hidden trap! You fall asleep...")
		"polymorph":
			_self_poly(_random_form(), POLY_SECONDS)
			_log("A hidden trap! Your body twists!")

func reveal_traps_near(cell: Vector2i, radius_tiles: int) -> void:
	for t in traps:
		if bool(t["revealed"]):
			continue
		var c: Vector2i = t["cell"]
		if maxi(absi(c.x - cell.x), absi(c.y - cell.y)) <= radius_tiles:
			t["revealed"] = true

func reveal_all_traps() -> void:
	for t in traps:
		t["revealed"] = true

func trap_at(cell: Vector2i):
	for t in traps:
		if t["cell"] == cell:
			return t
	return null

# --- shops / altar / fountain ---

func feature_near(cell: Vector2i):
	var best = null
	var best_d := 99
	for s in shops:
		var c: Vector2i = s["cell"]
		var d: int = maxi(absi(c.x - cell.x), absi(c.y - cell.y))
		if d <= 1 and d < best_d:
			best_d = d
			best = s
	return best

func room_index(cell: Vector2i) -> int:
	for i in range(_rooms.size()):
		var r: Array = _rooms[i]
		if cell.x >= int(r[0]) and cell.x < int(r[0]) + int(r[2]) and cell.y >= int(r[1]) and cell.y < int(r[1]) + int(r[3]):
			return i
	return -1

func price(base: int) -> int:
	if bool(talents.get("commerce", false)):
		return int(round(float(base) * 0.8))
	return base

func sell_price(base: int) -> int:
	if bool(talents.get("commerce", false)):
		return int(round(float(base) * 1.2))
	return base

func shop_buy(item: String, cost: int) -> bool:
	if int(inv.get("coins", 0)) < cost:
		_log("Not enough coins. (%d needed)" % cost)
		return false
	inv["coins"] = int(inv["coins"]) - cost
	inv[item] = int(inv.get(item, 0)) + 1
	_log("Bought %s for %d coins." % [String(FOOD_NAMES.get(item, item)), cost])
	return true

func shop_sell(item: String, value: int) -> bool:
	if int(inv.get(item, 0)) <= 0:
		_log("You have no %s to sell." % item)
		return false
	inv[item] = int(inv[item]) - 1
	inv["coins"] = int(inv.get("coins", 0)) + value
	_log("Sold %s for %d coins." % [item, value])
	return true

func altar_bless() -> bool:
	var cost := price(15)
	if int(inv.get("coins", 0)) < cost:
		_log("The altar wants %d coins." % cost)
		return false
	for k in identified.keys():
		if int(inv.get(k, 0)) > 0 and int(bless.get(k, 0)) == 0:
			inv["coins"] = int(inv["coins"]) - cost
			bless[k] = 1
			_log("The altar's light settles on your %s. It is blessed now." % display_name(k))
			return true
	_log("Nothing here to bless.")
	return false

func fountain_drink() -> bool:
	var r := rng.randf()
	if r < 0.40:
		_heal_player(20)
		_log("You drink. Cool water knits your wounds. (+20 HP)")
	elif r < 0.65:
		hunger = minf(HUNGER_MAX, hunger + 30.0)
		_log("You drink. Sweet water, oddly filling. (+30 hunger)")
	elif r < 0.85:
		_log("You drink. The water is cold and plain.")
	else:
		_log("You drink. The water shows you things — %s" % rumour())
	return true

# --- talents ---

func on_kill() -> bool:
	var new_level: int = int(main.kills) / KILLS_PER_LEVEL
	if new_level <= level:
		return false
	level = new_level
	_roll_talent_choices()
	_log("Level up! Press V to choose a talent. (%s)" % rumour())
	return true

func _roll_talent_choices() -> void:
	var pool: Array = []
	for t in TALENTS:
		if not bool(talents.get(t, false)):
			pool.append(t)
	_shuffle(pool)
	talent_choices = pool.slice(0, mini(3, pool.size()))

func apply_talent(tid: String) -> bool:
	if not talent_choices.has(tid):
		return false
	talents[tid] = true
	talent_choices.clear()
	_log("Talent learned: %s — %s" % [String(TALENT_NAMES.get(tid, tid)), String(TALENT_DESCS.get(tid, ""))])
	if tid == "trap_detection":
		reveal_all_traps()
	return true

func has_talent(tid: String) -> bool:
	return bool(talents.get(tid, false))

# --- drops (deterministic by spawn_id, never the global RNG) ---

func roll_drop(slug: String, spawn_id: int) -> Array:
	if spawn_id < 0:
		return []
	var drops: Array = []
	if spawn_id % 2 == 0:
		drops.append(["coins", 1 + spawn_id % 3])
	if spawn_id % 3 == 0 and slug in ["miner-ghoul", "rock-golem", "grave-revenant", "skeleton-warrior"]:
		drops.append(["meat", 1])
	if spawn_id % 4 == 0 and slug in ["cave-spider", "tunnel-worm"]:
		drops.append(["mushroom", 1])
	if spawn_id % 12 == 0 and slug in ["rock-golem", "ore-mimic"]:
		drops.append(["royal_jelly", 1])
	if spawn_id % 5 == 0:
		drops.append(["potion_" + POTION_APPS[spawn_id % 6], 1])
	if spawn_id % 8 == 0:
		drops.append(["wand_" + WAND_MATS[spawn_id % 4], 1])
	if spawn_id % 10 == 0:
		drops.append(["ring_" + RING_GEMS[spawn_id % 4], 1])
	if spawn_id % 6 == 0:
		drops.append(["scroll_" + SCROLL_KINDS[spawn_id % 4], 1])
	if slug == "rock-golem" and spawn_id % 7 == 0 and not control_ring_dropped:
		control_ring_dropped = true
		drops.append(["ring_control", 1])
	return drops

func on_collect(item: String) -> void:
	if bool(talents.get("literacy", false)) and identified.has(item):
		known[item] = true

# --- pets ---

func tame_pup() -> bool:
	if pet_tamed or not pet_alive:
		return false
	if int(inv.get("meat", 0)) <= 0:
		_log("The pup sniffs your hands. It wants meat.")
		return false
	inv["meat"] = int(inv["meat"]) - 1
	pet_tamed = true
	pet_hp = 30
	_log("You offer meat. The pup wolfs it down — and follows you now.")
	return true

func pet_died() -> void:
	pet_alive = false
	_log("Your pup is slain. It will not follow you again this run.")

# --- display names ---

func display_name(item: String) -> String:
	if FOOD_NAMES.has(item):
		return String(FOOD_NAMES[item])
	if item == "coins":
		return "Coins"
	if item == "ring_control":
		return "Control Ring"
	if item.begins_with("potion_"):
		if bool(known.get(item, false)):
			return "Potion of " + String(POTION_FX_NAMES.get(String(identified.get(item, "")), "?"))
		return String(item.trim_prefix("potion_")).capitalize() + " Potion"
	if item.begins_with("wand_"):
		if bool(known.get(item, false)):
			return "Wand of " + String(WAND_FX_NAMES.get(String(identified.get(item, "")), "?"))
		return String(item.trim_prefix("wand_")).capitalize() + " Wand"
	if item.begins_with("ring_"):
		if bool(known.get(item, false)):
			return "Ring of " + String(RING_FX_NAMES.get(String(identified.get(item, "")), "?"))
		return String(item.trim_prefix("ring_")).capitalize() + " Ring"
	if item.begins_with("scroll_"):
		return "Scroll of " + String(SCROLL_NAMES.get(String(item.trim_prefix("scroll_")), "?"))
	return item.capitalize()
