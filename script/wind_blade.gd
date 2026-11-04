extends "res://script/enemy_projectile.gd"

var _swirl: = 0.0
var _redraw_left: = 0.0

func _physics_process(delta: float) -> void :
	super._physics_process(delta)
	_swirl += delta * 19
	_redraw_left -= delta
	if _redraw_left <= 0:
		_redraw_left = 1.0 / 30.0
		queue_redraw()

func _draw() -> void :
	var points: = PackedVector2Array([Vector2(-10, -8), Vector2(7, -5), Vector2(12, 0), Vector2(7, 5), Vector2(-10, 8), Vector2(-3, 0)])
	draw_colored_polygon(points, Color(0.015, 0.03, 0.06))
	draw_polyline(PackedVector2Array([Vector2(-8, -6), Vector2(6, -3), Vector2(9, 0), Vector2(6, 3), Vector2(-8, 6)]), Color(1.0, 0.52, 0.62), 3.0, false)
	draw_line(Vector2(-3, 0), Vector2(7, 0), Color(0.92, 1.0, 1.0), 1.5, true)

	draw_arc(Vector2.ZERO, 12, _swirl, _swirl + PI * 0.9, 16, Color(0.55, 0.78, 0.68, 0.4), 1.4, false)
	draw_arc(Vector2.ZERO, 15, _swirl + PI, _swirl + PI * 1.7, 16, Color(0.72, 0.87, 0.81, 0.3), 1.0, false)
	draw_line(Vector2(-29, -5), Vector2(-12, -5), Color(0.55, 1, 0.85, 0.28), 1.5, false)
	draw_line(Vector2(-25, 5), Vector2(-10, 5), Color(0.55, 1, 0.85, 0.28), 1.5, false)
