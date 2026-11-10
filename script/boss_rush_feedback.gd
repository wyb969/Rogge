extends Node2D

var boss: Node2D
var half_size: = Vector2(53, 73)
var center_offset: = Vector2.ZERO
var _corners: = PackedVector2Array()
var _polygon: = PackedVector2Array()
var _outline: = PackedVector2Array()
var _panel: Control
var _title: Label
var _status: Label
var _progress: ProgressBar
var _last_caption: = ""
var _clock: = 0.0
var _redraw_left: = 0.0
var draw_calls_last: = 0
var _title_stamp: = -1

func _ready() -> void :
	top_level = true
	global_transform = Transform2D.IDENTITY
	z_index = 6
	_corners.resize(8)
	var hurt: CollisionShape2D = boss._hurt_area.get_node("CollisionShape2D")
	half_size = boss.collision_shape_2d.shape.get_rect().size * boss.collision_shape_2d.global_scale.abs() * 0.5 + hurt.shape.get_rect().size * hurt.global_scale.abs() * 0.5
	center_offset = boss.collision_shape_2d.global_position - boss.global_position - (hurt.global_position - boss.player.global_position)
	var layer: = CanvasLayer.new()
	layer.layer = 35
	add_child(layer)
	_panel = Control.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_panel)
	_title = Label.new()
	_status = Label.new()
	for label in [_title, _status]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_color_override("font_outline_color", Color(0.025, 0.035, 0.05))
		_panel.add_child(label)
	boss.health_bar.reparent(_panel, false)
	boss.health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress = ProgressBar.new()
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.show_percentage = false
	var back: = StyleBoxFlat.new()
	back.bg_color = Color(0.03, 0.045, 0.06, 0.9)
	var fill: = StyleBoxFlat.new()
	fill.bg_color = Color(1, 0.66, 0.3)
	fill.set_corner_radius_all(3)
	_progress.add_theme_stylebox_override("background", back)
	_progress.add_theme_stylebox_override("fill", fill)
	_panel.add_child(_progress)
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void :
	var vp: = get_viewport().get_visible_rect().size
	var scale_ui: = 1.5 if vp.y > vp.x else 1.0
	var width: = minf(480 * scale_ui, vp.x - 48)
	_panel.size = Vector2(width, 82 * scale_ui)
	_panel.position = Vector2((vp.x - width) * 0.5, vp.y - (270 if vp.y > vp.x else 108) * scale_ui)
	_title.size = Vector2(width, 26 * scale_ui)
	UiFonts.apply_to_label(_title, int(16 * scale_ui), true)
	boss.health_bar.position = Vector2(0, 28 * scale_ui)
	boss.health_bar.size = Vector2(width, 18 * scale_ui)
	_status.position = Vector2(0, 49 * scale_ui)
	_status.size = Vector2(width, 24 * scale_ui)
	UiFonts.apply_to_label(_status, int(12 * scale_ui), true)
	_progress.position = Vector2(0, 76 * scale_ui)
	_progress.size = Vector2(width, 5 * scale_ui)

func path_changed() -> void :
	var a: Vector2 = boss.global_position + center_offset
	var b: Vector2 = boss.target_position + center_offset
	for i in 4:
		var corner: = Vector2( - half_size.x if i % 2 == 0 else half_size.x, - half_size.y if i < 2 else half_size.y)
		_corners[i] = a + corner
		_corners[i + 4] = b + corner
	_polygon = Geometry2D.convex_hull(_corners)
	if _polygon.size() > 1 and _polygon[0] == _polygon[-1]: _polygon.resize(_polygon.size() - 1)
	_outline = _polygon.duplicate()
	_outline.append(_outline[0])
	queue_redraw()

func sweep_hits(a: Vector2, b: Vector2, hero: Vector2) -> bool:
	var relative: = hero - center_offset
	var lower: = relative - half_size
	var upper: = relative + half_size
	var motion: = b - a
	var first: = 0.0
	var last: = 1.0
	for axis in 2:
		if absf(motion[axis]) < 1e-05:
			if a[axis] < lower[axis] or a[axis] > upper[axis]: return false
		else:
			var start: float = (lower[axis] - a[axis]) / motion[axis]
			var finish: float = (upper[axis] - a[axis]) / motion[axis]
			first = maxf(first, minf(start, finish))
			last = minf(last, maxf(start, finish))
			if first > last: return false
	return true

func reset() -> void :
	_panel.hide()
	hide()
	set_process(false)

func _process(delta: float) -> void :
	if boss.is_dying: reset();return
	_clock += delta
	var warn: bool = boss.charge_state == boss.ChargeState.WARN
	var recover: bool = boss.charge_state == boss.ChargeState.RECOVER
	var locked: bool = boss.warning_locked
	var caption: = "逼近 · 保持距离"
	if warn: caption = ("锁定！横向移动" if boss._chain_warning else "锁定！横向冲刺") if locked else "蓄力追踪 · 准备闪避"
	elif recover: caption = "连冲蓄势 · 留意下一条路线" if boss._combo_left > 0 else "硬直 · 反击机会"
	elif boss.is_charging: caption = "冲锋！"
	if caption != _last_caption:
		_last_caption = caption
		_status.text = caption
		_status.add_theme_color_override("font_color", Color(1, 0.44, 0.3) if locked and warn else (GamePalette.PLAYER_CYAN if recover and boss._combo_left == 0 else Color(1, 0.85, 0.56)))
	var chained: bool = boss._combo_left > 0 or (boss._chain_warning and (warn or boss.is_charging))
	var title_stamp: int = int(boss.enraged()) * 2 + int(chained)
	if _title_stamp != title_stamp:
		_title_stamp = title_stamp
		_title.text = "狂奔巨蜥 / %s%s" % ["II" if boss.enraged() else "I", " · 连冲" if chained else ""]
	_progress.visible = warn
	if warn: _progress.value = (1 - boss._state_left / boss.warning_duration()) * 100
	_redraw_left -= delta
	if _redraw_left <= 0:
		_redraw_left = 1.0 / 30
		queue_redraw()

func _draw() -> void :
	draw_calls_last = 0
	if boss.is_dying: return
	if boss.charge_state == boss.ChargeState.WARN and _polygon.size() > 2:
		var locked: bool = boss.warning_locked
		var color: = Color(1, 0.25, 0.18) if locked else Color(1, 0.68, 0.26)
		draw_colored_polygon(_polygon, Color(color, 0.105 if locked else 0.055))
		draw_polyline(_outline, Color(0.025, 0.035, 0.05, 0.9), 4, false)
		draw_polyline(_outline, Color(color, 0.9), 1.6, false)
		var dir: Vector2 = boss.charge_direction
		var side: = dir.orthogonal()
		for i in 3:
			var t: float = (float(i) + 0.4) / 3
			if not locked: t = fposmod(t + _clock * 0.3, 1)
			var p: Vector2 = boss.global_position.lerp(boss.target_position, t)
			draw_line(p - dir * 8 - side * 6, p, Color(color, 0.95), 2, false)
			draw_line(p - dir * 8 + side * 6, p, Color(color, 0.95), 2, false)
		draw_calls_last = 9
	elif boss.charge_state == boss.ChargeState.RECOVER and boss._combo_left == 0:
		draw_arc(boss.global_position, 45, 0, TAU, 32, Color(GamePalette.PLAYER_CYAN, 0.4), 2, false)
		draw_calls_last = 1
