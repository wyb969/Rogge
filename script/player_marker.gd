extends Sprite2D

func _ready() -> void :
	texture = null
	scale = Vector2.ONE
	z_index = -1
	queue_redraw()
func _draw() -> void :
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.42))
	draw_arc(Vector2.ZERO, 10, 0.12, PI - 0.12, 16, GamePalette.alpha(GamePalette.PLAYER_PRIMARY,0.8), 1.2, false)
	draw_arc(Vector2.ZERO, 10, PI + 0.12, TAU - 0.12, 16, GamePalette.alpha(GamePalette.PLAYER_PRIMARY,0.8), 1.2, false)
