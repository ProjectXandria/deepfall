# pet.gd — DEEPFALL WazHack wave: the tamable dog pup.
# Wild at first (waits at its den); tame it with meat (X) or a
# taming scroll. Tamed it follows the player, attacks the nearest
# foe within 160 px (6 dmg, 1 s cooldown), senses hidden traps
# within 4 tiles, and has 30 HP — foes that strike the player while
# the pup is closer hit the pup instead (see enemy.gd _strike).
# Stuck or far behind (> 600 px, or no progress for 2 s) it scrambles
# back to the player's side. Dead until a new run.
extends Node2D

const TILE := 64
const GRAVITY := 1800.0
const PX_SCALE := 3.0
const FOLLOW_DIST := 180.0
const ATTACK_RANGE := 160.0
const ATTACK_DMG := 6
const ATTACK_COOLDOWN := 1.0
const WALK_SPEED := 200.0

var main_node: Node = null
var fg: Array = []
var player: Node2D = null
# Shift I: the world this mover collides in (see player.gd).
var world: int = DeepfallMapGen.MASK_AMBER
var world_mask: Array = []
var hp := 30
var max_hp := 30
var dead := false
var tamed := false
var vel := Vector2.ZERO
var facing := 1
var half_w := 14.0
var half_h := 16.0
var on_ground := false
var _idle_frame: Texture2D = null
var _walk_frames: Array = []
var _sprite: Sprite2D = null
var _anim_time := 0.0
var _moving := false
var _attack_timer := 0.0
var _cooldown_timer := 0.0
var _hurt_timer := 0.0
var _stuck_timer := 0.0
var _last_x := 0.0

func setup(p_main: Node, p_fg: Array, p_player: Node2D) -> void:
	main_node = p_main
	fg = p_fg
	player = p_player
	_idle_frame = load("res://assets/enemies_px/pet-dog/idle.png")
	_walk_frames = [load("res://assets/enemies_px/pet-dog/walk_0.png"),
		load("res://assets/enemies_px/pet-dog/walk_1.png")]
	_sprite = Sprite2D.new()
	_sprite.scale = Vector2(PX_SCALE, PX_SCALE)
	_sprite.texture = _idle_frame
	_sprite.position = Vector2(0, half_h - _idle_frame.get_height() * PX_SCALE * 0.5)
	add_child(_sprite)
	_last_x = position.x

func cell() -> Vector2i:
	return Vector2i(int(floor(position.x / TILE)), int(floor(position.y / TILE)))

func take_hit(dmg: int, from_x: float) -> void:
	if dead:
		return
	hp -= dmg
	_hurt_timer = 0.15
	var dir := 1.0 if position.x >= from_x else -1.0
	vel.x = dir * 300.0
	vel.y = -260.0
	on_ground = false
	if hp <= 0:
		hp = 0
		dead = true
		_sprite.visible = false
		if main_node != null and main_node.get("wz") != null:
			main_node.wz.pet_died()

func _physics_process(delta: float) -> void:
	_refresh_world()
	if dead or player == null:
		return
	_anim_time += delta
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_cooldown_timer = maxf(0.0, _cooldown_timer - delta)
	_attack_timer = maxf(0.0, _attack_timer - delta)
	vel.y += GRAVITY * delta
	if vel.y > 1200.0:
		vel.y = 1200.0
	_moving = false
	var to_player: Vector2 = player.position - position
	var dist := to_player.length()
	if not tamed:
		vel.x = 0.0
	elif dist > 600.0:
		# rubber-band: the pup scrambles back to your side
		position = player.position + Vector2(-40.0 * facing, -10.0)
		vel = Vector2.ZERO
		_stuck_timer = 0.0
	elif _attack_timer <= 0.0 and _cooldown_timer <= 0.0:
		var foe = _nearest_foe()
		if foe != null:
			_attack_timer = 0.35
			_cooldown_timer = ATTACK_COOLDOWN
			foe.take_hit(ATTACK_DMG, position.x)
			facing = 1 if foe.position.x >= position.x else -1
			vel.x = 0.0
		elif dist > FOLLOW_DIST:
			var dir := 1 if to_player.x > 0.0 else -1
			facing = dir
			vel.x = dir * WALK_SPEED
			_moving = true
		else:
			vel.x = 0.0
	else:
		vel.x = 0.0
	# stuck detection: no horizontal progress while trying to follow
	if tamed and _moving and absf(position.x - _last_x) < 1.0:
		_stuck_timer += delta
		if _stuck_timer > 2.0:
			position = player.position + Vector2(-40.0 * facing, -10.0)
			vel = Vector2.ZERO
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0
	_last_x = position.x
	_move_axis(delta, true)
	_move_axis(delta, false)
	_update_animation(delta)

func _nearest_foe():
	if main_node == null:
		return null
	var best = null
	var best_d := ATTACK_RANGE
	for e in main_node.enemies:
		if not is_instance_valid(e) or bool(e.get("dead")):
			continue
		var d: float = (e.position - position).length()
		if d < best_d:
			best_d = d
			best = e
	return best

# Shift I: refresh the cached world from main, once per physics
# frame (see player.gd).
func _refresh_world() -> void:
	if main_node == null:
		return
	world = int(main_node.get("current_world"))
	var wm: Variant = main_node.get("world_mask")
	if wm is Array:
		world_mask = wm

func _solid(cx: int, cy: int) -> bool:
	if cx < 0 or cx >= DeepfallMapGen.W or cy < 0 or cy >= DeepfallMapGen.H:
		return true
	var t: int = fg[cy][cx]
	if t == 0 or t == 7:
		return false
	# Shift I: a ghost cell is not solid in this world.
	if world_mask.is_empty():
		return true
	var m: int = world_mask[cy][cx]
	return m == DeepfallMapGen.MASK_BOTH or m == world

func _platform(cx: int, cy: int) -> bool:
	if cx < 0 or cx >= DeepfallMapGen.W or cy < 0 or cy >= DeepfallMapGen.H:
		return false
	if fg[cy][cx] != 7:
		return false
	# Shift I: a gated platform is standable only in its world.
	if world_mask.is_empty():
		return true
	var m: int = world_mask[cy][cx]
	return m == DeepfallMapGen.MASK_BOTH or m == world

func _move_axis(delta: float, x_axis: bool) -> void:
	if x_axis:
		position.x += vel.x * delta
		var top := int(floor((position.y - half_h) / TILE))
		var bot := int(floor((position.y + half_h - 1) / TILE))
		if vel.x > 0:
			var cx := int(floor((position.x + half_w) / TILE))
			for cy in range(top, bot + 1):
				if _solid(cx, cy):
					position.x = cx * TILE - half_w - 0.01
					vel.x = 0.0
					break
		elif vel.x < 0:
			var cx := int(floor((position.x - half_w) / TILE))
			for cy in range(top, bot + 1):
				if _solid(cx, cy):
					position.x = (cx + 1) * TILE + half_w + 0.01
					vel.x = 0.0
					break
	else:
		var prev_feet := position.y + half_h
		position.y += vel.y * delta
		var left := int(floor((position.x - half_w + 1) / TILE))
		var right := int(floor((position.x + half_w - 1) / TILE))
		on_ground = false
		if vel.y > 0:
			var cy := int(floor((position.y + half_h) / TILE))
			for cx in range(left, right + 1):
				if _solid(cx, cy) or (_platform(cx, cy) and prev_feet <= cy * TILE + 1):
					position.y = cy * TILE - half_h - 0.01
					vel.y = 0.0
					on_ground = true
					break
		elif vel.y < 0:
			var cy2 := int(floor((position.y - half_h) / TILE))
			for cx in range(left, right + 1):
				if _solid(cx, cy2):
					position.y = (cy2 + 1) * TILE + half_h + 0.01
					vel.y = 0.0
					break

func _update_animation(delta: float) -> void:
	var frames: Array = [_idle_frame]
	var fps := 1.0
	if _moving:
		frames = _walk_frames
		fps = 6.0
	var idx := 0 if frames.size() == 1 else int(_anim_time * fps) % frames.size()
	_sprite.texture = frames[idx]
	_sprite.flip_h = facing < 0
	if _hurt_timer > 0.0:
		_sprite.modulate = Color(1.0, 0.35, 0.35, 1.0)
	elif not tamed:
		_sprite.modulate = Color(0.85, 0.85, 0.9, 1.0)
	else:
		_sprite.modulate = Color(1, 1, 1, 1)
