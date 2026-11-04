extends "res://script/boss.gd"

enum AttackState{APPROACH, DASH_WINDUP, DASH, SLASH_WINDUP, SLASH, RECOVER, PHASE_SHIFT}
const MAX_HEALTH: = 3200.0
const PHASE_TWO_HEALTH: = 0.5
const SLASH_RADIUS: = 112.0
const SLASH_HALF_ANGLE: = PI * 0.36
const DASH_HALF_WIDTH: = 34.0
const DASH_MAX_DISTANCE: = 320.0
const PLAYER_RADIUS: = 14.0

var phase: int = 1
var attack_state: AttackState = AttackState.APPROACH
var state_left: float = 1.1
var state_duration: float = 1.1
var attack_angle: float = 0.0
var dash_distance_left: float = 0.0
var dash_distance: float = 0.0
var attack_hit: bool = false
var slash_count: int = 0
var dash_count: int = 0
var _anim_time: float = 0.0
var _sword: Node2D
var _title: Label
var _health_panel: Control

func configure_stage(_stage: int) -> void :
	fight_stage = 2

func _ready() -> void :
	fight_stage = 2
	health_max_value = MAX_HEALTH
	boss_current_health = health_max_value
	base_sprite_scale = sprite_2d.scale
	sprite_tint = Color.WHITE
	animation_player.stop()
	animation_player.active = false
	rush_timer.stop()
	_setup_health_bar()
	health_bar.size = Vector2(180, 26)
	health_bar.init_health(health_max_value)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.z_index = 21
	UiFonts.apply_to_label(_title, 17, true)
	_title.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04))
	_title.add_theme_constant_override("outline_size", 4)
	_title.text = "IRON KNIGHT  /  I"
	_build_boss_hud()
	_build_sword()

func deals_own_contact() -> bool:

	return true

func suspend_feedback() -> void :
	super.suspend_feedback()
	if is_instance_valid(_health_panel): _health_panel.hide()

func dash_windup_seconds() -> float:
	return 0.62 if phase == 2 else 0.85

func slash_windup_seconds() -> float:
	return 0.48 if phase == 2 else 0.72

func recovery_seconds() -> float:
	return 0.4 if phase == 2 else 0.82

func _process(delta: float) -> void :
	if is_dying:
		return
	_anim_time += delta
	var running: = attack_state == AttackState.DASH or attack_state == AttackState.APPROACH
	var frames: = 8 if running else 4
	sprite_2d.frame = (16 if running else 0) + int(_anim_time * (12.0 if running else 5.0)) % frames
	_sync_outline_frame_uv()
	var sweep: = clampf(1.0 - state_left / maxf(state_duration, 0.001), 0.0, 1.0)
	if _sword:
		_sword.rotation = attack_angle + lerpf( - SLASH_HALF_ANGLE, SLASH_HALF_ANGLE, sweep) if attack_state == AttackState.SLASH else attack_angle - SLASH_HALF_ANGLE
		_sword.modulate = Color(1.2, 0.92, 0.65) if phase == 2 else Color.WHITE
	queue_redraw()

func _physics_process(delta: float) -> void :
	if is_dying or not is_instance_valid(player) or player.player_health <= 0:
		return
	state_left -= delta
	match attack_state:
		AttackState.APPROACH:
			var offset: = player.global_position - global_position
			attack_angle = offset.angle()
			update_facing_direction(player.global_position)
			if offset.length() > 90.0:
				velocity = offset.normalized() * (82.0 if phase == 2 else 64.0) * poison_slow
				move_and_slide()
			else:
				velocity = Vector2.ZERO
			if state_left <= 0.0:
				if offset.length() > 155.0:
					_begin_dash()
				else:
					_begin_slash()
		AttackState.DASH_WINDUP:
			if state_left <= 0.0:
				attack_hit = false
				dash_count += 1
				_set_state(AttackState.DASH, 1.0)
		AttackState.DASH:
			var dir: = Vector2.RIGHT.rotated(attack_angle)
			var step: = minf((650.0 if phase == 2 else 520.0) * delta, dash_distance_left)
			var before: = global_position
			var collision: = move_and_collide(dir * step)
			dash_distance_left -= before.distance_to(global_position)
			if not attack_hit and Geometry2D.get_closest_point_to_segment(player.global_position, before, global_position).distance_to(player.global_position) <= DASH_HALF_WIDTH + PLAYER_RADIUS:
				_hit_player(95.0 if phase == 2 else 80.0)
			if dash_distance_left <= 0.5 or collision != null or state_left <= 0.0:
				velocity = Vector2.ZERO
				_begin_slash()
		AttackState.SLASH_WINDUP:
			if state_left <= 0.0:
				attack_hit = false
				slash_count += 1
				_set_state(AttackState.SLASH, 0.2 if phase == 2 else 0.26)
		AttackState.SLASH:

			if not attack_hit and slash_contains(player.global_position):
				_hit_player(90.0 if phase == 2 else 75.0)
			if state_left <= 0.0:
				_set_state(AttackState.RECOVER, recovery_seconds())
		AttackState.RECOVER:
			if state_left <= 0.0:
				_set_state(AttackState.APPROACH, 0.25 if phase == 2 else 0.45)
		AttackState.PHASE_SHIFT:
			if state_left <= 0.0:
				_title.text = "IRON KNIGHT  /  II"
				_set_state(AttackState.APPROACH, 0.3)

func _set_state(next: AttackState, duration: float) -> void :
	attack_state = next
	state_duration = duration
	state_left = duration
	velocity = Vector2.ZERO
	queue_redraw()

func _begin_dash() -> void :
	var offset: = player.global_position - global_position
	attack_angle = offset.angle()
	dash_distance = clampf(offset.length(), 130.0, DASH_MAX_DISTANCE)
	dash_distance_left = dash_distance
	update_facing_direction(player.global_position)
	_set_state(AttackState.DASH_WINDUP, dash_windup_seconds())

func _begin_slash() -> void :

	attack_angle = (player.global_position - global_position).angle()
	update_facing_direction(player.global_position)
	_set_state(AttackState.SLASH_WINDUP, slash_windup_seconds())

func slash_contains(world_point: Vector2) -> bool:
	var offset: = world_point - global_position
	return offset.is_zero_approx() or (offset.length() <= SLASH_RADIUS and absf(wrapf(offset.angle() - attack_angle, - PI, PI)) <= SLASH_HALF_ANGLE)

func _hit_player(amount: float) -> void :
	attack_hit = true
	player.receive_attack(amount, self)

func apply_hit(hit_data: Dictionary) -> void :
	super.apply_hit(hit_data)
	if is_dying:
		_sword.visible = false
		_title.visible = false
		queue_redraw()
	if not is_dying and phase == 1 and boss_current_health <= health_max_value * PHASE_TWO_HEALTH:
		phase = 2
		_title.text = "PHASE II  /  ENRAGED"
		_title.add_theme_color_override("font_color", Color(1.0, 0.62, 0.25))
		_apply_phase2_outline()

		_set_state(AttackState.PHASE_SHIFT, 1.1)

func _apply_phase2_outline() -> void :

	if phase == 2:
		super._apply_phase2_outline()

func _on_rush_timer_timeout() -> void :
	pass

func _draw() -> void :
	if is_dying:
		return
	draw_ellipse_shadow()
	var warning: = attack_state == AttackState.DASH_WINDUP or attack_state == AttackState.SLASH_WINDUP
	var active: = attack_state == AttackState.SLASH
	if not warning and not active:
		return
	var fill: = Color(1.0, 0.08, 0.12, 0.3 + 0.12 * (1.0 - state_left / maxf(state_duration, 0.001)))
	var edge: = Color(1.0, 0.24, 0.28, 1.0)
	if active:
		fill = Color(1.0, 0.72, 0.22, 0.48)
		edge = Color(1.0, 0.94, 0.68)
	var points: = PackedVector2Array()
	if attack_state == AttackState.DASH_WINDUP:
		var dir: = Vector2.RIGHT.rotated(attack_angle)
		var side: = dir.orthogonal() * (DASH_HALF_WIDTH + PLAYER_RADIUS)
		points = PackedVector2Array([ - side, dir * dash_distance - side, dir * dash_distance + side, side])
	else:
		points.append(Vector2.ZERO)
		for i in range(33):
			var angle: = attack_angle + lerpf( - SLASH_HALF_ANGLE, SLASH_HALF_ANGLE, float(i) / 32.0)
			points.append(Vector2.RIGHT.rotated(angle) * SLASH_RADIUS)
	draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, Color(0.08, 0.01, 0.03, 0.95), 6.0, true)
	draw_polyline(points, edge, 2.5, true)

func draw_ellipse_shadow() -> void :
	draw_set_transform(Vector2(0, 44), 0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 42.0, Color(0.015, 0.015, 0.025, 0.5))
	draw_set_transform(Vector2.ZERO)

func _build_sword() -> void :
	_sword = Node2D.new()
	_sword.name = "Sword"
	_sword.position = Vector2(0, 8)
	_sword.z_index = 6
	add_child(_sword)

	for part in [
		[PackedVector2Array([Vector2(20, -8), Vector2(82, -8), Vector2(92, 0), Vector2(82, 8), Vector2(20, 8)]), Color(0.08, 0.1, 0.17)], 
		[PackedVector2Array([Vector2(24, -5), Vector2(80, -5), Vector2(88, 0), Vector2(80, 5), Vector2(24, 5)]), Color(0.8, 0.89, 1.0)], 
		[PackedVector2Array([Vector2(25, -4), Vector2(78, -4), Vector2(85, 0), Vector2(25, 0)]), Color(1, 1, 1)], 
		[PackedVector2Array([Vector2(18, -14), Vector2(25, -14), Vector2(25, 14), Vector2(18, 14)]), Color(0.95, 0.65, 0.2)], 
		[PackedVector2Array([Vector2(4, -4), Vector2(18, -4), Vector2(18, 4), Vector2(4, 4)]), Color(0.38, 0.2, 0.12)], 
	]:
		var polygon: = Polygon2D.new()
		polygon.polygon = part[0]
		polygon.color = part[1]
		_sword.add_child(polygon)

func _build_boss_hud() -> void :

	var canvas: = CanvasLayer.new()
	canvas.layer = 35
	add_child(canvas)
	_health_panel = Control.new()
	_health_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_health_panel)
	health_bar.reparent(_health_panel, false)
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_panel.add_child(_title)
	get_viewport().size_changed.connect(_layout_boss_hud)
	_layout_boss_hud()

func _layout_boss_hud() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var width: = minf(460.0, vp.x - 48.0)
	var bottom: = 170.0 if vp.y > vp.x else 20.0
	_health_panel.position = Vector2((vp.x - width) * 0.5, vp.y - bottom - 64.0)
	_health_panel.size = Vector2(width, 64)
	_title.position = Vector2.ZERO
	_title.size = Vector2(width, 28)
	health_bar.position = Vector2(0, 32)
	health_bar.size = Vector2(width, 26)
