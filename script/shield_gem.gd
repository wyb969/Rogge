extends Node2D
## Translucent jade diamond drawn over the player while a kill shield is up.

func _process(_delta: float) -> void:
	if not visible:
		return
	var t := Time.get_ticks_msec() * 0.004
	scale = Vector2.ONE * (1.0 + sin(t) * 0.07)
	rotation = sin(t * 0.35) * 0.1
	queue_redraw()

func _draw() -> void:
	var outer := PackedVector2Array([
		Vector2(0, -36),
		Vector2(28, -2),
		Vector2(0, 40),
		Vector2(-28, -2),
	])
	var inner := PackedVector2Array([
		Vector2(0, -16),
		Vector2(12, 0),
		Vector2(0, 18),
		Vector2(-12, 0),
	])
	draw_colored_polygon(outer, Color(0.78, 0.95, 0.38, 0.30))
	var outline := outer.duplicate()
	outline.append(outer[0])
	draw_polyline(outline, Color(0.98, 1.0, 0.62, 0.75), 2.0, true)
	draw_colored_polygon(inner, Color(1.0, 0.97, 0.72, 0.28))
	draw_line(Vector2(0, -36), Vector2(0, 40), Color(1.0, 1.0, 0.85, 0.35), 1.5)
	draw_line(Vector2(-28, -2), Vector2(28, -2), Color(1.0, 1.0, 0.85, 0.28), 1.2)
