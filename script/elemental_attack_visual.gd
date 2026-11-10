extends Node2D


const MAX_SHAPES: = 5
const MAX_DRAW_CALLS: = 112
const RED: = preload("res://script/visual_style.gd").DANGER
const INK: = Color(0.025, 0.035, 0.07, 0.9)
const PALETTE: = [GamePalette.ENEMY_RED, GamePalette.ENEMY_ORANGE, GamePalette.TELEGRAPH_EDGE, GamePalette.ENEMY_AMBER]
var geometry: Array[Dictionary] = []
var element: = 0
var active: = false
var mode: = "area"
var age: = 0.0
var duration: = 0.3
var draw_calls_last: = 0
var build_count: = 0
var _detail: Array[Dictionary] = []
var _rng: = RandomNumberGenerator.new()
var _redraw_left: = 0.0
var _dive_from: = Vector2.ZERO
var _dive_to: = Vector2.ZERO

func _ready() -> void :
	add_to_group("elemental_attack_visual")
	top_level = true
	global_transform = Transform2D.IDENTITY
	z_index = 4
	_rng.randomize()
	clear()

func prepare(kind: int, shapes: Array[Dictionary], attack_mode: String = "area") -> void :
	clear()
	element = clampi(kind, 0, 3)
	mode = attack_mode
	geometry.assign(shapes.slice(0, MAX_SHAPES).duplicate(true))
	build_count += 1
	for shape in geometry:
		var item: = {"outline": PackedVector2Array(), "fill": PackedVector2Array(), "bolts": []}
		if shape.kind == "lane":
			item.fill = _capsule(shape.a, shape.b, shape.width)
			item.outline = item.fill.duplicate()
			item.outline.append(item.outline[0])

		for variant in range(3 if element == 1 else 0):
			var points: = PackedVector2Array()
			if shape.kind == "lane":
				var tangent: Vector2 = (shape.b - shape.a).normalized()
				for i in 17:
					points.append(shape.a.lerp(shape.b, float(i) / 16) + tangent.orthogonal() * _rng.randf_range(-0.7, 0.7) * float(shape.width))
			else:
				for i in 9:
					points.append(shape.center + Vector2(_rng.randf_range(-5, 5), - float(shape.radius) * (0.9 - float(i) * 0.1125)))
			item.bolts.append(points)
		_detail.append(item)
	visible = not geometry.is_empty()
	queue_redraw()

func activate(seconds: float) -> void :
	active = true

	z_index = 6 if mode == "dive" else 4
	age = 0
	duration = maxf(seconds, 0.01)
	_redraw_left = 0
	set_process(true)
	queue_redraw()

func set_dive_segment(before: Vector2, after: Vector2) -> void :
	_dive_from = before
	_dive_to = after
	queue_redraw()

func clear() -> void :
	active = false
	z_index = 4
	age = 0
	geometry.clear()
	_detail.clear()
	draw_calls_last = 0
	visible = false
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void :
	age += delta
	_redraw_left -= delta
	if _redraw_left <= 0:
		_redraw_left = 1.0 / 30.0
		queue_redraw()

func _capsule(a: Vector2, b: Vector2, radius: float) -> PackedVector2Array:
	var points: = PackedVector2Array()
	var angle: = (b - a).angle()
	for i in 13:
		points.append(b + Vector2.from_angle(angle - PI * 0.5 + PI * i / 12) * radius)
	for i in 13:
		points.append(a + Vector2.from_angle(angle + PI * 0.5 + PI * i / 12) * radius)
	return points

func _draw() -> void :
	draw_calls_last = 0
	if geometry.is_empty(): return
	var tint: Color = PALETTE[element]
	var edge: = RED

	var guidance: = active and mode != "area"
	for index in geometry.size():
		_footprint(geometry[index], _detail[index], edge, 0.035 if guidance else (0.12 if active else 0.09), guidance)
	if not active: return
	if mode == "projectile": return
	if mode == "dive":
		_draw_dive(tint)
		return
	for index in geometry.size():
		var shape: Dictionary = geometry[index]
		match element:
			0: _water(shape, tint)
			1: _thunder(shape, _detail[index], tint)
			2: _wind_lane(shape, tint)
			3: _fire(shape, tint)

func _footprint(shape: Dictionary, detail: Dictionary, tint: Color, alpha: float, guidance: bool) -> void :
	var edge: = Color(tint, 0.22 if guidance else 0.92)
	if shape.kind == "lane":
		_polygon(detail.fill, Color(tint, alpha))
		if not guidance: _line(detail.outline, INK, 4)
		_line(detail.outline, edge, 1.7)
	elif shape.kind == "ring":

		_arc(shape.center, (shape.radius + shape.inner) * 0.5, 0, TAU, Color(tint, alpha), shape.radius - shape.inner)
		for radius in [shape.inner, shape.radius]:
			_arc(shape.center, radius, 0, TAU, INK, 4)
			_arc(shape.center, radius, 0, TAU, edge, 1.7)
	else:
		_circle(shape.center, shape.radius, Color(tint, alpha))
		_arc(shape.center, shape.radius, 0, TAU, INK, 4)
		_arc(shape.center, shape.radius, 0, TAU, edge, 1.7)

func _water(shape: Dictionary, tint: Color) -> void :
	if shape.kind == "lane":
		var a: Vector2 = shape.a
		var delta: Vector2 = shape.b - a
		var side: = delta.normalized().orthogonal()
		for i in 5:
			var travel: = fposmod(age * 2.4 + float(i) / 5, 1)
			var center: = a + delta * travel
			var width: float = shape.width * 0.88
			var forward: = delta.normalized()
			_line(PackedVector2Array([center - side * width - forward * 4, center - side * width * 0.5 + forward * 2, center + forward * 4, center + side * width * 0.5 + forward * 2, center + side * width - forward * 4]), Color(0.78, 0.98, 1, 0.9), 3)
		return
	var radius: float = shape.radius
	var center: Vector2 = shape.center
	var rise: = sin(clampf(age / duration, 0, 1) * PI * 0.75)
	_arc(center, radius * (0.45 + 0.45 * rise), 0, TAU, Color(0.72, 0.98, 1, 0.9), 2)
	for side in [-1, 0, 1]:
		var base: = center + Vector2(side * radius * 0.44, radius * 0.1)
		var height: = radius * (0.95 if side == 0 else 0.65) * (0.5 + rise * 0.5)
		var width: = radius * 0.15
		_polygon(PackedVector2Array([base + Vector2( - width, 0), base + Vector2( - width * 0.65, - height * 0.7), base + Vector2( - width * 1.6, - height), base + Vector2(0, - height * 0.84), base + Vector2(width * 1.6, - height), base + Vector2(width * 0.6, - height * 0.65), base + Vector2(width, 0)]), Color(tint, 0.9))
		_line(PackedVector2Array([base, base + Vector2( - width * 0.15, - height * 0.6), base + Vector2( - width * 0.8, - height * 0.9)]), Color(0.85, 1, 1), 2.3)

func _thunder(shape: Dictionary, detail: Dictionary, tint: Color) -> void :
	var points: PackedVector2Array = detail.bolts[int(age / 0.055) % 3]
	_line(points, Color(0.15, 0.035, 0.27, 0.9), 5)
	_line(points, Color(tint, 0.9), 2.8)
	_line(points, Color(0.95, 0.93, 0.88), 1.0)
	if shape.kind == "lane":
		var normal: Vector2 = (shape.b - shape.a).normalized().orthogonal()
		for i in [4, 8, 12]:
			_line(PackedVector2Array([points[i] - normal * shape.width * 0.7, points[i], points[i] + normal * shape.width * 0.7]), Color(tint, 0.85), 2)
	else:
		_arc(shape.center, shape.radius * (0.65 + sin(age * 40) * 0.12), age * 18, age * 18 + TAU * 0.8, Color(0.95, 0.83, 1), 2.5)

func _fire(shape: Dictionary, tint: Color) -> void :
	if shape.kind == "ring":
		for i in 12:
			var angle: = TAU * i / 12.0
			var radius: = lerpf(shape.inner + 12, shape.radius - 12, 0.5 + sin(i * 2.1) * 0.35)
			_flame(shape.center + Vector2.from_angle(angle) * radius, 10, minf(25 + sin(age * 32 + i) * 6, shape.radius - radius - 3), tint, angle + PI * 0.5)
		for i in 2:
			var radius: float = lerpf(shape.inner + 3, shape.radius - 3, fposmod(age * 3 + i * 0.5, 1))
			_arc(shape.center, radius, 0, TAU, Color(1, 0.79, 0.25, 0.7), 2)
	else:
		for i in 3:
			var at: Vector2 = shape.center + Vector2((i - 1) * shape.radius * 0.3, shape.radius * 0.25)
			_flame(at, float(shape.radius) * 0.2, float(shape.radius) * (1.0 + sin(age * 28 + i) * 0.15), tint)

func _flame(at: Vector2, width: float, height: float, tint: Color, angle: float = 0) -> void :
	var outer: = PackedVector2Array([Vector2( - width, 2), Vector2( - width * 0.8, - height * 0.45), Vector2( - width * 0.1, - height * 0.28), Vector2(width * 0.2, - height), Vector2(width * 0.8, - height * 0.55), Vector2(width, 2)])
	var core: = PackedVector2Array([Vector2( - width * 0.45, 0), Vector2(width * 0.1, - height * 0.53), Vector2(width * 0.5, 0)])
	for i in outer.size(): outer[i] = at + outer[i].rotated(angle)
	for i in core.size(): core[i] = at + core[i].rotated(angle)
	_polygon(outer, Color(tint, 0.95))
	_polygon(core, Color(1, 0.9, 0.4))

func _wind_lane(shape: Dictionary, tint: Color) -> void :
	if shape.kind != "lane": return
	var delta: Vector2 = shape.b - shape.a
	var side: = delta.normalized().orthogonal()
	for i in 4:
		var point: Vector2 = shape.a + delta * fposmod(age * 2.8 + i * 0.25, 1)
		_line(PackedVector2Array([point - side * shape.width * 0.7 - delta.normalized() * 8, point, point + side * shape.width * 0.7 - delta.normalized() * 8]), Color(tint, 0.9), 2.5)

func _draw_dive(tint: Color) -> void :
	_circle(_dive_to, 30, Color(tint, 0.07))
	var direction: = (_dive_to - _dive_from).normalized()
	_line(PackedVector2Array([_dive_from, _dive_to]), Color(tint, 0.13), 18)
	for i in 3:
		var start: = age * 21 + i * TAU / 3
		_arc(_dive_to, 24 + i * 3, start, start + PI * 0.8, Color(tint, 0.9), 2.5)
		_line(PackedVector2Array([_dive_to - direction * (12 + i * 7) - direction.orthogonal() * 8, _dive_to + direction * 12 + direction.orthogonal() * (i - 1) * 7]), Color(0.9, 1, 0.95, 0.6), 1.5)
	if element == 0:
		_arc(_dive_to, 22, 0, TAU, Color(0.78, 0.98, 1, 0.7), 2)
	elif element == 1:
		for i in 2:
			var side: = direction.orthogonal() * float(i * 2 - 1)
			_line(PackedVector2Array([_dive_to - side * 8, _dive_to + side * 10 - direction * 5, _dive_to + side * 18 + direction * 7]), Color(1, 0.86, 0.4, 0.85), 2)
	elif element == 3:
		for i in 2: _flame(_dive_to - direction * (15 + i * 12), 7, 18, tint, direction.angle() - PI * 0.5)

func _line(points: PackedVector2Array, color: Color, width: float) -> void :
	if draw_calls_last >= MAX_DRAW_CALLS: return
	draw_calls_last += 1
	draw_polyline(points, color, width, false)

func _arc(center: Vector2, radius: float, start: float, end: float, color: Color, width: float) -> void :
	if draw_calls_last >= MAX_DRAW_CALLS: return
	draw_calls_last += 1
	draw_arc(center, radius, start, end, 48, color, width, false)

func _circle(center: Vector2, radius: float, color: Color) -> void :
	if draw_calls_last >= MAX_DRAW_CALLS: return
	draw_calls_last += 1
	draw_circle(center, radius, color, true, -1, false)

func _polygon(points: PackedVector2Array, color: Color) -> void :
	if draw_calls_last >= MAX_DRAW_CALLS: return
	draw_calls_last += 1
	draw_colored_polygon(points, color)
