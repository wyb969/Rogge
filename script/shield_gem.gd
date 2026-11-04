extends Node2D

var _outer: = PackedVector2Array([Vector2(0, -23), Vector2(18, 0), Vector2(0, 25), Vector2(-18, 0)])
var _outline: = PackedVector2Array([Vector2(0, -23), Vector2(18, 0), Vector2(0, 25), Vector2(-18, 0), Vector2(0, -23)])

func _process(_delta: float) -> void :
	if not visible:
		return
	var t: = Time.get_ticks_msec() * 0.004
	scale = Vector2.ONE * (1.0 + sin(t) * 0.02)
	rotation = 0

func _draw() -> void :
	draw_colored_polygon(_outer, Color(0.62, 0.79, 0.63, 0.035))
	draw_polyline(_outline, Color(0.09, 0.13, 0.17, 0.65), 2.7, false)
	draw_polyline(_outline, Color(0.75, 0.86, 0.66, 0.68), 1.0, false)
