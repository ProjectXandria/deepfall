# fx.gd — DEEPFALL Phase 11 game-feel helpers ("juice").
# Pixel debris bursts (block chips, sparks, dust), floating damage /
# pickup text, pickup flyers that pop out and home to the player,
# screen shake (read by player.gd into the camera offset) and hit-stop.
extends Node2D

var main_node: Node = null
var shake_vec := Vector2.ZERO
var _shake := 0.0
var _parts: Array = []
var _texts: Array = []
var _flyers: Array = []
var _hitstop_left := 0.0
# Phase 12: sound + rumble (settings pushed in by touch_ui)
var volume := 0.8
var vibration := true
var _streams: Dictionary = {}
var _players: Array = []
var _next_player := 0
var _last_play: Dictionary = {}
# Phase 13: looping cave ambience (drone / drips / rumble), mixed by depth
var music := 0.6
var _amb: Dictionary = {}
var _depth_s := 0.0
# Graphics Push 1 (GP3): ambient dust motes + crystal sparkle, 0 new
# nodes, 0 new lights, still 1 _draw call. 28 deterministic motes
# (RNG seed 20261101), slow drift, wrapped around the camera view.
const GP_MOTE_COUNT := 28
var _gp_motes: Array = []
var _gp_time := 0.0

func gp_mote_count() -> int:
	return _gp_motes.size()

func _gp_init_motes() -> void:
	if not _gp_motes.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261101
	for i in range(GP_MOTE_COUNT):
		_gp_motes.append({
			"o": Vector2(rng.randf_range(0.0, 1280.0), rng.randf_range(0.0, 720.0)),
			"v": Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-6.0, 2.0)),
			"s": rng.randf_range(2.0, 4.0),
			"a": rng.randf_range(0.12, 0.25),
			"ph": rng.randf_range(0.0, TAU),
		})

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var tu: Node = main_node.get_node_or_null("TouchUI") if main_node != null else null
	if tu != null and tu.get("settings") is Dictionary:
		var st: Dictionary = tu.get("settings")
		volume = float(st.get("volume", 0.8))
		vibration = bool(st.get("vibration", true))
		music = float(st.get("music", 0.6))
	for n in ["drone", "drips", "rumble"]:
		var w: AudioStreamWAV = load("res://assets/sfx/amb_%s.wav" % n)
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(round(w.get_length() * w.mix_rate))
		var ap2 := AudioStreamPlayer.new()
		ap2.stream = w
		ap2.volume_db = -80.0
		add_child(ap2)
		ap2.play()
		_amb[n] = ap2
	for n in ["swing", "mine_hit", "mine_break", "hit", "hurt", "jump", "land", "dash", "slam", "pickup", "prop_break", "enemy_die"]:
		_streams[n] = load("res://assets/sfx/%s.wav" % n)
	for i in range(10):
		var ap := AudioStreamPlayer.new()
		add_child(ap)
		_players.append(ap)
	_gp_init_motes()

func sfx(name: String, pitch_var := 0.08, vol_db := 0.0) -> void:
	if volume <= 0.01 or not _streams.has(name):
		return
	# throttle identical sounds to one per 40 ms (multi-hits stay clean)
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(name, -1000)) < 40:
		return
	_last_play[name] = now
	var ap: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	ap.stream = _streams[name]
	ap.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	ap.volume_db = linear_to_db(volume) + vol_db
	ap.play()

# depth_t: 0 = surface rooms, 1 = the deepest row. Deeper = lower,
# darker drone, louder distant rumbles, slightly fewer/duller drips.
func update_ambience(depth_t: float) -> void:
	if _amb.is_empty():
		return
	_depth_s = lerpf(_depth_s, depth_t, 0.02)
	var t := _depth_s if absf(_depth_s - depth_t) > 0.001 else depth_t
	var m: float = maxf(0.0001, music)
	_amb["drone"].pitch_scale = lerpf(1.0, 0.72, t)
	_amb["drone"].volume_db = linear_to_db(m * 0.55)
	_amb["drips"].pitch_scale = lerpf(1.0, 0.85, t)
	_amb["drips"].volume_db = linear_to_db(m * lerpf(0.5, 0.3, t))
	_amb["rumble"].volume_db = linear_to_db(m * lerpf(0.08, 0.75, t))

func rumble(ms: int) -> void:
	if vibration:
		Input.vibrate_handheld(ms)

func shake(amount: float) -> void:
	_shake = minf(18.0, maxf(_shake, amount))

func hitstop(t: float) -> void:
	if _hitstop_left > 0.0 or t <= 0.0:
		return
	_hitstop_left = t
	Engine.time_scale = 0.08
	var tm := get_tree().create_timer(t, true, false, true)
	tm.timeout.connect(_end_hitstop)

func _end_hitstop() -> void:
	_hitstop_left = 0.0
	Engine.time_scale = 1.0

# Square pixel chips with gravity + ground bounce (cheap: Polygon-free
# draw in _draw, one node for every particle).
func burst(pos: Vector2, col: Color, count: int, speed: float, grav := 1400.0, size := 6.0, life := 0.6, up_bias := 0.6) -> void:
	for i in range(count):
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a) - up_bias) * speed * randf_range(0.4, 1.0)
		var c := col.lerp(Color.WHITE if randf() < 0.3 else Color.BLACK, randf() * 0.25)
		_parts.append({"p": pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), "v": v,
			"c": c, "t": 0.0, "life": life * randf_range(0.7, 1.2), "g": grav, "s": size * randf_range(0.6, 1.1)})
	if _parts.size() > 500:
		_parts = _parts.slice(_parts.size() - 500)

func float_text(pos: Vector2, text: String, col: Color, big := false) -> void:
	_texts.append({"p": pos, "text": text, "c": col, "t": 0.0, "big": big, "vx": randf_range(-30, 30)})

func flyer(pos: Vector2, col: Color, label: String) -> void:
	_flyers.append({"p": pos, "v": Vector2(randf_range(-120, 120), randf_range(-380, -260)),
		"c": col, "t": 0.0, "label": label})

func _process(delta: float) -> void:
	var rd: float = delta / maxf(0.01, Engine.time_scale)
	_shake = maxf(0.0, _shake - rd * 40.0)
	shake_vec = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	# GP3: dust motes drift slowly, wrapped around the 1280x720 camera
	# view (offsets are view-relative; world pos is derived in _draw).
	_gp_time += delta
	for m in _gp_motes:
		var o: Vector2 = m["o"] + (m["v"] as Vector2) * delta
		o.x = fposmod(o.x, 1280.0)
		o.y = fposmod(o.y, 720.0)
		m["o"] = o
	var fg: Array = main_node.fg if main_node != null else []
	for p in _parts:
		p["t"] = float(p["t"]) + delta
		var v: Vector2 = p["v"]
		v.y += float(p["g"]) * delta
		var np: Vector2 = p["p"] + v * delta
		# bounce off solid blocks (floor) with damping
		if not fg.is_empty():
			var cx := int(floor(np.x / 64.0)); var cy := int(floor(np.y / 64.0))
			if cx >= 0 and cx < DeepfallMapGen.W and cy >= 0 and cy < DeepfallMapGen.H and fg[cy][cx] != 0 and fg[cy][cx] != 7:
				v.y = -v.y * 0.35
				v.x *= 0.6
				np = p["p"]
		p["v"] = v
		p["p"] = np
	_parts = _parts.filter(func(p): return float(p["t"]) < float(p["life"]))
	for t in _texts:
		t["t"] = float(t["t"]) + delta
		t["p"] = (t["p"] as Vector2) + Vector2(float(t["vx"]), -70.0 * (1.0 - float(t["t"]))) * delta
	_texts = _texts.filter(func(t): return float(t["t"]) < 0.9)
	var pl: Node2D = main_node.get("player") if main_node != null else null
	for f in _flyers:
		f["t"] = float(f["t"]) + delta
		var v: Vector2 = f["v"]
		if float(f["t"]) < 0.3 or pl == null:
			v.y += 1500.0 * delta
			v *= 0.98
		else:
			var to: Vector2 = (pl.position + Vector2(0, -10)) - (f["p"] as Vector2)
			v = v.lerp(to.normalized() * 900.0, minf(1.0, 8.0 * delta))
			if to.length() < 24.0:
				f["done"] = true
				sfx("pickup", 0.1, -4.0)
				float_text(pl.position + Vector2(0, -60), String(f["label"]), Color(1, 0.95, 0.7))
		f["v"] = v
		f["p"] = (f["p"] as Vector2) + v * delta
	_flyers = _flyers.filter(func(f): return not f.has("done") and float(f["t"]) < 2.0)
	queue_redraw()

func _draw() -> void:
	# GP3: dust motes (view-relative offsets wrapped in _process) and
	# crystal sparkle — same single _draw call as the particles.
	var cam: Node = main_node.get("camera") if main_node != null else null
	var cc := Vector2(640, 360)
	if cam != null and cam.has_method("get_screen_center_position"):
		cc = cam.get_screen_center_position()
	var origin: Vector2 = cc - Vector2(640, 360)
	for m in _gp_motes:
		var tw := 0.75 + 0.25 * sin(_gp_time * 1.3 + float(m["ph"]))
		var mp: Vector2 = origin + (m["o"] as Vector2)
		draw_circle(mp, float(m["s"]), Color(0.85, 0.9, 1.0, float(m["a"]) * tw))
	if main_node != null and main_node.get("_crystal_cells") != null:
		var cells: Array = main_node.get("_crystal_cells")
		for c in cells:
			var wp := Vector2((int(c.x) + 0.5) * 64.0, (int(c.y) + 0.5) * 64.0)
			if wp.distance_to(cc) > 900.0:
				continue
			var k := 0.5 + 0.5 * sin(_gp_time * 2.0 + float(int(c.x) * 7 + int(c.y) * 13))
			var sa := 0.3 + 0.4 * k
			var sl := 6.0 + 4.0 * k
			var scol := Color(0.5, 0.95, 1.0, sa)
			draw_line(wp + Vector2(-sl, 0), wp + Vector2(sl, 0), scol, 2.0)
			draw_line(wp + Vector2(0, -sl), wp + Vector2(0, sl), scol, 2.0)
	for p in _parts:
		var k: float = 1.0 - float(p["t"]) / float(p["life"])
		var s: float = maxf(2.0, float(p["s"]) * (0.5 + 0.5 * k))
		var c: Color = p["c"]
		c.a = clampf(k * 1.5, 0.0, 1.0)
		var pp: Vector2 = (p["p"] as Vector2).round()
		draw_rect(Rect2(pp - Vector2(s, s) * 0.5, Vector2(s, s)), c)
	for f in _flyers:
		var pp: Vector2 = (f["p"] as Vector2).round()
		var bob := sin(float(f["t"]) * 10.0) * 2.0
		draw_rect(Rect2(pp + Vector2(-9, -9 + bob), Vector2(18, 18)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(pp + Vector2(-7, -7 + bob), Vector2(14, 14)), f["c"])
		draw_rect(Rect2(pp + Vector2(-7, -7 + bob), Vector2(5, 5)), Color(1, 1, 1, 0.5))
	var font := ThemeDB.fallback_font
	for t in _texts:
		var k: float = 1.0 - float(t["t"]) / 0.9
		var c: Color = t["c"]
		c.a = clampf(k * 2.0, 0.0, 1.0)
		var fs := 26 if bool(t["big"]) else 18
		var pp: Vector2 = (t["p"] as Vector2).round()
		draw_string_outline(font, pp, String(t["text"]), HORIZONTAL_ALIGNMENT_CENTER, -1, fs, 6, Color(0, 0, 0, c.a))
		draw_string(font, pp, String(t["text"]), HORIZONTAL_ALIGNMENT_CENTER, -1, fs, c)
