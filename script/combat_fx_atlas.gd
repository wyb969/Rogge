extends RefCounted

# Four columns of 112 px cells. Use the combat clock for pause, hitstop and cancellation.
const CELL := 112
const COLUMNS := 4

static func frame(texture: Texture2D, progress: float) -> Rect2:
	var count := COLUMNS * int(texture.get_height() / CELL)
	var index := clampi(floori(progress * count), 0, count - 1)
	return Rect2((index % COLUMNS) * CELL, floori(float(index) / COLUMNS) * CELL, CELL, CELL)

# The sweep sprites are painted in a shallow frame; restore their world-space aspect.
static func sweep(canvas: Node2D, texture: Texture2D, center: Vector2, heading: float, radius: float, progress: float) -> void:
	var unit := radius / 102.0
	var dest := Rect2(-2.0 * unit, -110.0 * unit, CELL * unit, 2.0 * CELL * unit)
	canvas.draw_set_transform(center, heading)
	canvas.draw_texture_rect_region(texture, dest, frame(texture, progress), Color(1, 1, 1, 1.0 - smoothstep(0.67, 1.0, progress)))
	canvas.draw_set_transform(Vector2.ZERO)
