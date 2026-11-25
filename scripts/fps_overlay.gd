# FPS overlay — diagnostic tool, NOT gameplay. Self-contained: it samples
# frame times in its own _process (its CanvasLayer runs PROCESS_MODE_ALWAYS
# so it keeps drawing while the run card pauses the tree) and draws FPS +
# frame ms + a rolling frame-time graph with chunk-crossing markers.
# Toggle: MENU -> SETTINGS -> "FPS overlay (frame graph)", or F8 on desktop.
# Default ON so Skit sees it immediately on his phone. It never touches
# game state — display only, one small Control redraw per frame.
extends Control

const HIST_N := 120
const GRAPH_MS_MAX := 100.0
const _GREEN_MS := 16.7
const _YELLOW_MS := 33.3

var _hist := PackedFloat32Array()
var _sample_n := 0
var _fps_smooth := 60.0
var _marks: Array = []  # {"sample": int, "hitch": float}
var _crossing_watch := 0.0
var _crossing_max := 0.0
var _last_crossing_ms := 0.0
var _crossing_count := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Top-right, below the SAVE/NEW/MENU button row (buttons end y=58).
	offset_left = -296.0
	offset_right = -16.0
	offset_top = 66.0
	offset_bottom = 198.0

func note_crossing() -> void:
	# Called by main on every stream-chunk crossing. The next 0.5 s of
	# frames are watched; the worst frame in that window is the crossing
	# hitch, marked on the graph as a white line.
	_crossing_watch = 0.5
	_crossing_max = 0.0
	_crossing_count += 1

func set_overlay_visible(v: bool) -> void:
	visible = v

func is_overlay_visible() -> bool:
	return visible

func _process(delta: float) -> void:
	if get_tree().paused or delta <= 0.0001:
		return
	var ms := delta * 1000.0
	_hist.append(ms)
	if _hist.size() > HIST_N:
		_hist.remove_at(0)
	_sample_n += 1
	_fps_smooth = lerpf(_fps_smooth, 1.0 / delta, 0.1)
	if _crossing_watch > 0.0:
		_crossing_watch -= delta
		_crossing_max = maxf(_crossing_max, ms)
		if _crossing_watch <= 0.0:
			_last_crossing_ms = _crossing_max
			_marks.append({"sample": _sample_n, "hitch": _crossing_max})
	while not _marks.is_empty() and _sample_n - int(_marks[0]["sample"]) > HIST_N:
		_marks.remove_at(0)
	queue_redraw()

func _mean_ms() -> float:
	if _hist.is_empty():
		return 0.0
	var s := 0.0
	for v in _hist:
		s += v
	return s / float(_hist.size())

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var w := size.x
	var h := size.y
	# Panel.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.border_color = Color(1, 1, 1, 0.25)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(8)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	var tx := 10.0
	var ty := 22.0
	var fps_txt := "FPS %.0f  %.1f ms" % [_fps_smooth, _mean_ms()]
	draw_string(font, Vector2(tx, ty), fps_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.95))
	var cross_txt := "crossings %d  last hitch %.0f ms" % [_crossing_count, _last_crossing_ms]
	draw_string(font, Vector2(tx, ty + 18.0), cross_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.9, 1, 0.8))
	# Graph area.
	var gx0 := 10.0
	var gx1 := w - 10.0
	var gy0 := 52.0
	var gy1 := h - 10.0
	var gh := gy1 - gy0
	# Reference lines: 16.7 ms (60 fps) and 33.3 ms (30 fps).
	for ref in [_GREEN_MS, _YELLOW_MS]:
		var ry := gy1 - gh * clampf(ref / GRAPH_MS_MAX, 0.0, 1.0)
		draw_line(Vector2(gx0, ry), Vector2(gx1, ry), Color(1, 1, 1, 0.25), 1.0)
	# Frame bars, newest on the right.
	var bw := (gx1 - gx0) / float(HIST_N)
	for i in range(_hist.size()):
		var ms: float = _hist[i]
		var bh := gh * clampf(ms / GRAPH_MS_MAX, 0.0, 1.0)
		var col := Color(0.35, 0.9, 0.45, 0.9)
		if ms >= _YELLOW_MS:
			col = Color(0.95, 0.35, 0.3, 0.9)
		elif ms >= _GREEN_MS:
			col = Color(0.95, 0.8, 0.3, 0.9)
		var bx := gx0 + float(i) * bw
		draw_rect(Rect2(bx, gy1 - bh, maxf(bw - 0.5, 0.5), bh), col)
	# Crossing markers: white vertical line at the crossing sample.
	for m in _marks:
		var age := _sample_n - int(m["sample"])
		if age < 0 or age > HIST_N:
			continue
		var mx := gx1 - float(age) * bw
		draw_line(Vector2(mx, gy0), Vector2(mx, gy1), Color(1, 1, 1, 0.95), 2.0)
