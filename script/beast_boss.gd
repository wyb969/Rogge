extends "res://script/boss.gd"

const NAMES: = ["潮汐巨象 / TIDE", "雷鬃狮王 / THUNDER", "苍穹灵隼 / GALE", "熔岩玄龟 / AEGIS"]
const IDS: = ["tide", "thunder", "gale", "aegis"]
const HP: = [3600.0, 4200.0, 4800.0, 5600.0]
const COLORS: = [Color(0.28, 0.85, 0.95), Color(1.0, 0.83, 0.3), Color(0.6, 1.0, 0.78), Color(1.0, 0.56, 0.26)]
const ROAM_SPEEDS: = [65.0, 96.0, 80.0, 43.0]
const STANDOFFS: = [170.0, 145.0, 180.0, 110.0]
const DIVE_SPEEDS: = [330.0, 470.0, 450.0, 260.0]
enum State{APPROACH, WARN, ACTIVE, RECOVER, PHASE}
var element: = 0
var phase: = 1
var state: = State.APPROACH
var state_left: = 1.2
var pattern_index: = 1
var shapes: Array[Dictionary] = []
var dive: = false
var _extra_dives: = 0
var dive_start: = Vector2.ZERO
var dive_end: = Vector2.ZERO
var _attack_hit: = false
var _hud: Control
var _title: Label
var _elapsed: = 0.0
const ATTACK_VISUAL: = preload("res://script/elemental_attack_visual.gd")
var attack_visual: Node2D
var _visual_state: = -1
var _move_name: = ""
var _action_label: Label
var _caption_state: = -1
var _caption_move: = ""
var _active_duration: = 0.3

func _death_stain_kind() -> StringName:
	return StringName(IDS[element])

func configure_stage(stage: int) -> void :
	fight_stage = stage
	element = clampi(stage - 3, 0, 3)

func _ready() -> void :
	animation_player.stop()
	animation_player.active = false
	rush_timer.stop()
	health_max_value = HP[element]
	boss_current_health = health_max_value
	sprite_2d.frame = 0
	sprite_2d.hframes = 1
	sprite_2d.vframes = 1
	sprite_2d.texture = load("res://assest/sprites/beasts/%s.svg" % IDS[element])
	sprite_2d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_2d.scale = Vector2.ONE * 0.9
	base_sprite_scale = sprite_2d.scale
	sprite_tint = Color.WHITE
	_setup_health_bar()
	health_bar.init_health(health_max_value)
	_build_hud()
	add_to_group("beast_boss")
	attack_visual = ATTACK_VISUAL.new()
	attack_visual.name = "ElementalAttackVisual"
	add_child(attack_visual)

func deals_own_contact() -> bool:
	return true

func suspend_feedback() -> void :
	super.suspend_feedback()
	if is_instance_valid(_hud): _hud.hide()
	if is_instance_valid(attack_visual): attack_visual.clear()

func warning_seconds() -> float:
	return 0.75 if phase == 2 else 1.0

func roaming_seconds() -> float:
	return 0.95 if phase == 2 else 1.25

func dive_speed() -> float:
	if element == 2: return 600.0 if phase == 2 else 450.0
	return DIVE_SPEEDS[element] * (1.18 if phase == 2 else 1.0)

func _reposition(_delta: float, weight: float = 1.0) -> void :
	var offset: = player.global_position - global_position
	var distance: = offset.length()
	var dir: = offset / distance if distance > 0.001 else Vector2.RIGHT
	var preferred: float = STANDOFFS[element]
	var radial: = clampf((distance - preferred) / 80.0, -1, 1)
	var side: = 1.0 if pattern_index % 2 == 0 else -1.0
	var heading: = dir * radial + dir.orthogonal() * side * (0.9 if absf(radial) < 0.65 else 0.3)
	var speed: float = ROAM_SPEEDS[element] * (1.22 if phase == 2 else 1.0)
	velocity = heading.normalized() * speed * poison_slow * weight
	move_and_slide()
	if absf(offset.x) > 2: sprite_2d.flip_h = offset.x < 0

func _process(delta: float) -> void :
	_elapsed += delta
	_update_attack_visual()
	if _action_label != null and (_caption_state != state or _caption_move != _move_name):
		_caption_state = state
		_caption_move = _move_name
		var caption: String = ["走位", "预警 · " + _move_name, "释放 · " + _move_name, "硬直 · 反击", "二阶段"][state]
		_action_label.text = caption
	if not is_dying:
		sprite_2d.position.y = sin(_elapsed * 2.5) * (5.0 if element == 2 else 2.0)
		if dive and state == State.ACTIVE:
			var progress: = clampf(1 - state_left / _active_duration, 0, 1)
			if element == 3: sprite_2d.rotation = progress * TAU * 2
			elif element == 1: sprite_2d.position.y -= sin(progress * PI) * 14
			elif element == 0: sprite_2d.rotation = sin(progress * PI) * signf(dive_end.x - dive_start.x) * 0.14
		else: sprite_2d.rotation = lerp_angle(sprite_2d.rotation, 0, minf(1, delta * 14))
	queue_redraw()

func _physics_process(delta: float) -> void :
	if is_dying or not is_instance_valid(player) or player.player_health <= 0.0 or get_tree().paused:
		return
	state_left -= delta
	match state:
		State.APPROACH:
			_reposition(delta)
			if state_left <= 0:
				begin_attack()
		State.WARN:
			if state_left <= 0:
				state = State.ACTIVE
				state_left = clampf(dive_start.distance_to(dive_end) / dive_speed() + 0.05, 0.3, 1.3) if dive else 0.3
				_active_duration = state_left
				_attack_hit = false
		State.ACTIVE:
			if dive:
				var before: = global_position
				global_position = global_position.move_toward(dive_end, dive_speed() * delta)
				attack_visual.set_dive_segment(before, global_position)
				if not _attack_hit and Geometry2D.get_closest_point_to_segment(player.global_position, before, global_position).distance_to(player.global_position) <= 30.0:
					_hit()
			elif not _attack_hit and attack_contains(player.global_position):
				_hit()
			if state_left <= 0.0:
				shapes.clear()
				if dive and _extra_dives > 0:
					_extra_dives -= 1
					_prepare_dive(player.global_position)
					state = State.WARN
					state_left = warning_seconds()
				else:
					state = State.RECOVER
					state_left = 0.58 if phase == 2 else 1.0
		State.RECOVER:

			if state_left < 0.3 and element != 2: _reposition(delta, 0.45)
			if state_left <= 0:
				state = State.APPROACH
				state_left = roaming_seconds()
		State.PHASE:
			if state_left <= 0:
				state = State.APPROACH
				state_left = 0.4
	_update_attack_visual()
	queue_redraw()

func begin_attack() -> void :
	shapes.clear()
	dive = false
	_extra_dives = 0
	var target: = player.global_position
	var aim: = (target - global_position).normalized()
	if aim.is_zero_approx():
		aim = Vector2.DOWN
	var count: = 5 if phase == 2 else 3
	var alternate: = pattern_index % 3 == 2
	if element != 2 and pattern_index % 3 == 1:
		_prepare_dive(target)
		_extra_dives = 1 if element == 1 and phase == 2 else 0
		_move_name = ["潮涌冲锋", "雷跃突袭", "俯冲", "熔壳滚动"][element]
		pattern_index += 1
		state = State.WARN
		state_left = warning_seconds()
		velocity = Vector2.ZERO
		_update_attack_visual(true)
		queue_redraw()
		return
	_move_name = ["水泡落点" if not alternate else "潮汐水道", "交叉落雷" if not alternate else "雷印追击", "风刃", "熔岩环" if not alternate else "火种坠落"][element]
	match element:
		0:
			if alternate:
				_lanes(global_position, aim, 3 if phase == 2 else 1, 80.0, 22.0)
			else:
				_circles(target, count, 30.0)
		1:
			if alternate:
				_circles(target, count, 34.0)
			else:
				var dir: = Vector2.from_angle(PI * 0.25 if phase == 2 else 0.0)
				for axis in [dir, dir.orthogonal()]:
					shapes.append({"kind": "lane", "a": target - axis * 240, "b": target + axis * 240, "width": 23.0})
		2:
			if alternate:
				_extra_dives = 1 if phase == 2 else 0
				_prepare_dive(target)
			else:
				_lanes(target - aim * 200, aim, count, 65.0, 20.0)
		3:
			if alternate:
				_circles(target, count, 36.0)
			else:
				var inner: = 75.0
				var outer: = 140.0
				if phase == 2 and pattern_index % 4 == 2:
					inner = 40.0
					outer = 95.0
				shapes.append({"kind": "ring", "center": global_position, "radius": outer, "inner": inner})
	pattern_index += 1
	state = State.WARN
	state_left = warning_seconds()
	velocity = Vector2.ZERO
	_update_attack_visual(true)
	queue_redraw()

func _update_attack_visual(force: bool = false) -> void :
	if attack_visual == null: return
	var next_state: int = -1 if is_dying else int(state)
	if not force and _visual_state == next_state: return
	_visual_state = next_state
	if next_state == State.WARN:
		var mode: = "dive" if dive else ("projectile" if get("role") == 0 else "area")
		attack_visual.prepare(element, shapes, mode)
		attack_visual.set_dive_segment(global_position, global_position)
	elif next_state == State.ACTIVE:
		attack_visual.activate(state_left)
	else:
		attack_visual.clear()

func _prepare_dive(target: Vector2) -> void :
	dive = true
	var aim: = (target - global_position).normalized()
	if aim.is_zero_approx():
		aim = Vector2.DOWN
	dive_start = global_position
	dive_end = global_position + aim * clampf(global_position.distance_to(target) + 65.0, 120.0, 300.0)
	shapes.append({"kind": "lane", "a": dive_start, "b": dive_end, "width": 30.0})

func _lanes(origin: Vector2, dir: Vector2, count: int, gap: float, width: float) -> void :
	for i in count:
		var side: = dir.orthogonal() * (float(i) - float(count - 1) * 0.5) * gap
		shapes.append({"kind": "lane", "a": origin + side, "b": origin + dir * 420 + side, "width": width})

func _circles(target: Vector2, count: int, radius: float) -> void :
	shapes.append({"kind": "circle", "center": target, "radius": radius})
	for i in count - 1:
		var offset: = Vector2.from_angle(TAU * float(i) / float(count - 1) + float(pattern_index) * 0.45) * 85.0
		shapes.append({"kind": "circle", "center": target + offset, "radius": radius})

func attack_contains(point: Vector2) -> bool:
	for shape in shapes:
		if shape.kind == "lane":
			if Geometry2D.get_closest_point_to_segment(point, shape.a, shape.b).distance_to(point) <= float(shape.width):
				return true
		else:
			var distance: = point.distance_to(shape.center)
			if distance <= float(shape.radius) and (shape.kind != "ring" or distance >= float(shape.inner)):
				return true
	return false

func _hit() -> void :
	_attack_hit = true
	player.receive_attack(65.0 + float(element) * 8.0 + (15.0 if phase == 2 else 0.0), self)

func apply_hit(data: Dictionary) -> void :
	super.apply_hit(data)
	if is_dying:
		shapes.clear()
		_hud.hide()
	elif phase == 1 and boss_current_health <= health_max_value * 0.5:
		phase = 2
		shapes.clear()
		dive = false
		_extra_dives = 0
		state = State.PHASE
		state_left = 1.1
		_title.text = NAMES[element] + " / II"
		_title.add_theme_color_override("font_color", COLORS[element])
	_update_attack_visual()
	queue_redraw()

func _apply_phase2_outline() -> void :
	pass

func _on_rush_timer_timeout() -> void :
	pass

func _draw() -> void :
	if is_dying:
		return
	draw_set_transform(Vector2(0, 44), 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, 46, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	if phase == 2:
		draw_arc(Vector2.ZERO, 62.0 + sin(_elapsed * 5) * 3, 0, TAU, 48, Color(COLORS[element], 0.6), 2.0, true)
func _build_hud() -> void :
	var layer: = CanvasLayer.new()
	layer.layer = 35
	add_child(layer)
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	health_bar.reparent(_hud, false)
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = Label.new()
	_title.text = NAMES[element] + " / I"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_to_label(_title, 18, true)
	_title.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	_title.add_theme_constant_override("outline_size", 5)
	_hud.add_child(_title)
	_action_label = Label.new()
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.84))
	_action_label.add_theme_constant_override("outline_size", 3)
	_action_label.add_theme_color_override("font_outline_color", Color(0.025, 0.035, 0.05))
	UiFonts.apply_to_label(_action_label, 12, true)
	_hud.add_child(_action_label)
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()

func _layout_hud() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var width: = minf(480, vp.x - 48)
	_hud.position = Vector2((vp.x - width) * 0.5, vp.y - (220 if vp.y > vp.x else 92))
	_title.size = Vector2(width, 30)
	health_bar.position = Vector2(0, 34)
	health_bar.size = Vector2(width, 26)
	_action_label.position = Vector2(0, 63)
	_action_label.size = Vector2(width, 20)
