extends Sprite2D

func _ready() -> void :
	texture = null
	scale = Vector2.ONE
	z_index = -1
	queue_redraw()
func _draw() -> void :
	draw_set_transform(Vector2(0, 12), 0, Vector2(1.15, 0.38))
	draw_circle(Vector2.ZERO, 11.0, GamePalette.shadow(0.82))
	draw_set_transform(Vector2.ZERO)
	var diamond := PackedVector2Array([Vector2(0, -16), Vector2(12, 0), Vector2(0, 13), Vector2(-12, 0)])
	draw_polyline(diamond, GamePalette.MARKER_GOLD, 1.6, true)
