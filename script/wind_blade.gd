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
	draw_colored_polygon(points, GamePalette.INK)
	draw_polyline(PackedVector2Array([Vector2(-8, -6), Vector2(6, -3), Vector2(9, 0), Vector2(6, 3), Vector2(-8, 6)]), GamePalette.DANGER_ORANGE, 3.0, false)
	draw_line(Vector2(-3, 0), Vector2(7, 0), GamePalette.PLAYER_DAMAGE_WHITE, 1.5, true)

	draw_arc(Vector2.ZERO, 12, _swirl, _swirl + PI * 0.9, 16, GamePalette.alpha(GamePalette.DANGER_ORANGE, 0.4), 1.4, false)
	draw_arc(Vector2.ZERO, 15, _swirl + PI, _swirl + PI * 1.7, 16, GamePalette.alpha(GamePalette.DANGER_ORANGE, 0.3), 1.0, false)
	draw_line(Vector2(-29, -5), Vector2(-12, -5), GamePalette.alpha(GamePalette.DANGER_ORANGE, 0.28), 1.5, false)
	draw_line(Vector2(-25, 5), Vector2(-10, 5), GamePalette.alpha(GamePalette.DANGER_ORANGE, 0.28), 1.5, false)
