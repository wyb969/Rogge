extends Node2D

const DURATION: = 0.82
const GREEN: = Color(0.36, 0.91, 0.64)
const LIGHT: = Color(0.78, 1.0, 0.86)
const SCREEN_ALPHA: = 0.035
const MAX_DRAW_CALLS: = 24
var age: = DURATION
var kind: = 0
var casts_started: = 0
var draw_calls_last: = 0
var _drop: = PackedVector2Array([Vector2(0, -13), Vector2(-7, -2), Vector2(-8, 5), Vector2(-4, 10), Vector2(4, 10), Vector2(8, 5), Vector2(7, -2), Vector2(0, -13)])
var _bolt: = PackedVector2Array([Vector2(3, -13), Vector2(-7, 1), Vector2(0, 1), Vector2(-3, 13), Vector2(8, -3), Vector2(1, -3)])
var _shield: = PackedVector2Array([Vector2(0, -13), Vector2(11, -7), Vector2(9, 6), Vector2(0, 13), Vector2(-9, 6), Vector2(-11, -7), Vector2(0, -13)])

func _ready() -> void :
	z_index = 8
	set_process(false)

func play(index: int) -> void :
	kind = clampi(index, 0, 3)
	age = 0
	casts_started += 1
	queue_redraw()

func reset() -> void :
	age = DURATION
	draw_calls_last = 0
	queue_redraw()

func advance(delta: float) -> void :
	if age >= DURATION: return
	age = minf(DURATION, age + maxf(0, delta))
	queue_redraw()

func opacity() -> float:
	return smoothstep(0, 0.11, age) * (1 - smoothstep(0.28, DURATION, age)) if age < DURATION else 0.0

func _line(a: Vector2, b: Vector2, color: Color, width: float = 1.4) -> void :
	draw_calls_last += 1
	draw_line(a, b, color, width, false)

func _arc(radius: float, start: float, end: float, color: Color, width: float = 1.4) -> void :
	draw_calls_last += 1
	draw_arc(Vector2.ZERO, radius, start, end, 24, color, width, false)

func _glyph(points: PackedVector2Array, alpha: float) -> void :
	draw_calls_last += 2
	draw_polyline(points, Color(0.06, 0.17, 0.12, alpha * 0.9), 3.2, false)
	draw_polyline(points, Color(LIGHT, alpha * 0.9), 1.4, false)

func _draw() -> void :
	draw_calls_last = 0
	var alpha: = opacity()
	if alpha <= 0: return
	var t: = age / DURATION
	var radius: = 10 + 42 * (1 - pow(1 - t, 3))

	draw_set_transform(Vector2(0, 8 - t * 18), 0, Vector2(1, 0.82))
	for i in 3:
		var angle: = age * 2.1 + TAU * float(i) / 3
		_arc(radius, angle, angle + TAU * 0.26, Color(GREEN, alpha * 0.68), 1.6)
	_arc(radius * 0.72, - age * 3, - age * 3 + TAU * 0.65, Color(GREEN, alpha * 0.32), 1)
	for i in 4:
		var direction: = Vector2.from_angle(TAU * float(i) / 4 + 0.4)
		_line(direction * (radius + 2), direction * (radius + 6), Color(LIGHT, alpha * 0.65), 1.2)
	draw_set_transform(Vector2(0, -7), 0, Vector2.ONE * (0.78 + 0.22 * smoothstep(0, 0.22, age)))
	match kind:
		0:
			_glyph(_drop, alpha)
			_line(Vector2(-3, 2), Vector2(3, 2), Color(LIGHT, alpha))
			_line(Vector2(0, -1), Vector2(0, 5), Color(LIGHT, alpha))
		1:
			_glyph(_bolt, alpha)
			_line(Vector2(-12, -9), Vector2(-9, -6), Color(GREEN, alpha * 0.8))
			_line(Vector2(10, 7), Vector2(13, 10), Color(GREEN, alpha * 0.8))
		2:
			for i in 3:
				var angle: = - age * 5 + TAU * float(i) / 3
				_arc(8 + float(i) * 3, angle, angle + PI * 1.2, Color(LIGHT, alpha * 0.85), 1.6)
		3:
			_glyph(_shield, alpha)
			_line(Vector2(0, -6), Vector2(0, 7), Color(GREEN, alpha * 0.8), 1.3)
	draw_set_transform(Vector2.ZERO)
