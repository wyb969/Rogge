extends Node2D

const VORTEX := preload("res://rogge_art/combat-fx/blood-vortex/vortex.png")
const CLEAVE := preload("res://rogge_art/combat-fx/blood-vortex/cleave.png")
const CELL := 128
const COLUMNS := 6
const CUT_TIME := 0.36

var _age := 0.0
var _duration := 1.0
var _pulse_age := -10.0
var _cut_age := -1.0
var _radius := 1.0
var _heading := Vector2.RIGHT
var _frame := 0

func _ready() -> void:
	z_index = 12
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clear()

func begin(at: Vector2, heading: Vector2, radius: float) -> void:
	global_position = at
	_heading = heading.normalized() if not heading.is_zero_approx() else Vector2.RIGHT
	_radius = radius
	_age = 0.0
	_frame = 0
	_cut_age = -1.0
	_pulse_age = -10.0
	show()
	set_process(false)
	queue_redraw()

func advance(age: float, duration: float) -> void:
	_age = age
	_duration = duration
	var frame := floori(age * 24.0) % 24
	if frame != _frame:
		_frame = frame
		queue_redraw()

func pulse() -> void:
	_pulse_age = _age
	queue_redraw()

func finish() -> void:
	_cut_age = 0.0
	set_process(true)
	queue_redraw()

func clear() -> void:
	_cut_age = -1.0
	set_process(false)
	hide()

func _process(delta: float) -> void:
	_cut_age += delta
	if _cut_age >= CUT_TIME:
		clear()
	else:
		queue_redraw()

func _stamp(sheet: Texture2D, frame: int, size: float, tint := Color.WHITE) -> void:
	var region := Rect2(frame % COLUMNS * CELL, floori(frame / float(COLUMNS)) * CELL, CELL, CELL)
	draw_texture_rect_region(sheet, Rect2(Vector2.ONE * -size * 0.5, Vector2.ONE * size), region, tint)

func _draw() -> void:
	var angle := _heading.angle()
	# Mirror the left-facing sword so its finishing stroke still kicks upward.
	var mirror := Vector2.ONE
	if _heading.x < 0.0:
		angle = (-_heading).angle()
		mirror.x = -1.0
	draw_set_transform(Vector2.ZERO, angle, mirror)
	if _cut_age >= 0.0:
		var t := _cut_age / CUT_TIME
		if t < 0.32:
			_stamp(VORTEX, _frame, 2.12 * _radius * (1.0 - t * 2.6), Color(1, 0.70, 0.70, 1.0 - t * 3.0))
		_stamp(CLEAVE, mini(11, floori(t * 12.0)), _radius * 2.46)
	else:
		var hit := 1.0 - smoothstep(0.0, 0.21, _age - _pulse_age)
		var draw_in := smoothstep(0.0, 0.19, _age)
		var release := smoothstep(_duration - 0.17, _duration, _age)
		var scale_factor := (0.48 + 0.52 * draw_in) * (1.0 - 0.12 * hit - 0.14 * release)
		_stamp(VORTEX, _frame, 2.21 * _radius * scale_factor, Color(1, 1 + 0.52 * hit, 1 + 0.32 * hit, 0.23 + 0.77 * draw_in))
		if hit > 0.0:
			var n := _radius * (0.12 + hit * 0.19)
			draw_colored_polygon(PackedVector2Array([Vector2(-n, 2), Vector2(-3, -2), Vector2(n, -n * 0.42), Vector2(2, 3)]), Color(1.0, 0.76, 0.60, hit))
