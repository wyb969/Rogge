extends Node2D

const VORTEX := preload("res://rogge_art/combat-fx/blood-vortex/vortex.png")
const CLEAVE := preload("res://rogge_art/combat-fx/blood-vortex/cleave.png")
const VORTEX_CELL := Vector2(164, 88)
const CLEAVE_CELL := Vector2(128, 128)
const COLUMNS := 6
const CUT_TIME := 0.36

var _age := 0.0
var _duration := 1.0
var _pulse_age := -10.0
var _cut_age := -1.0
var _radius := 1.0
var _length := 1.0
var _heading := Vector2.RIGHT
var _frame := 0

func _ready() -> void:
	z_index = 12
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clear()

func begin(at: Vector2, heading: Vector2, length: float, max_radius: float) -> void:
	global_position = at
	_heading = heading.normalized() if not heading.is_zero_approx() else Vector2.RIGHT
	_radius = max_radius
	_length = length
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

func _stamp(sheet: Texture2D, frame: int, size: Vector2, tint := Color.WHITE) -> void:
	var cell := VORTEX_CELL if sheet == VORTEX else CLEAVE_CELL
	var region := Rect2(Vector2(frame % COLUMNS, floori(frame / float(COLUMNS))) * cell, cell)
	draw_texture_rect_region(sheet, Rect2(-size * 0.5, size), region, tint)

func _draw() -> void:
	var angle := _heading.angle()
	# Mirror the left-facing sword so its finishing stroke still kicks upward.
	var mirror := Vector2.ONE
	if _heading.x < 0.0:
		angle = (-_heading).angle()
		mirror.x = -1.0
	draw_set_transform(Vector2.ZERO, angle, mirror)
	# Atlas coordinates run from the sword (-length/2) to the lip (+length/2).
	# Pulses squeeze the helix across its axis; every turn retains its reach.
	var size := Vector2(_length, _radius * 144.0 / 70.0)
	if _cut_age >= 0.0:
		var t := clampf(_cut_age / CUT_TIME, 0.0, 1.0)
		var coil_frame := (_frame + floori(_cut_age * 25.0)) % 24
		var fading := 1.0 - smoothstep(0.08, 0.86, t)
		if fading > 0.0:
			_stamp(VORTEX, coil_frame, Vector2(size.x, size.y * (1.0 - 0.28 * t)), Color(1.0, 0.87, 0.84, fading))
		_stamp(CLEAVE, mini(11, floori(t * 12)), Vector2.ONE * _radius * 2.65)
	else:
		var hit := 1.0 - smoothstep(0.0, 0.21, _age - _pulse_age)
		var draw_in := smoothstep(0.0, 0.13, _age)
		var release := smoothstep(_duration - 0.17, _duration, _age)
		size.y *= (0.92 + 0.08 * draw_in) * (1.0 - 0.045 * hit - 0.045 * release)
		_stamp(VORTEX, _frame, size, Color(1, 1 + 0.52 * hit, 1 + 0.32 * hit, 0.79 + 0.21 * draw_in))
