extends Node2D

const FLASH := preload("res://rogge_art/combat-fx/draw-slash/flash.png")
const IMPACT_TIME := 0.06
const CELL := 160
# On the original grid, the cutting edge reaches 71 pixels from the grip.
const EDGE_RADIUS := 71.0
const FRAME_ENDS := [0.032, IMPACT_TIME, 0.08, 0.10, 0.126, 0.153, 0.181, 0.206, 0.231, 0.257, 0.286, 0.32]

var _age := 0.0
var _frame := 0
var _size := Vector2.ZERO
var _facing := 1.0

func _ready() -> void:
	z_index = 14
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clear()

func play(at: Vector2, radius: float, facing: float) -> void:
	global_position = at
	_age = 0.0
	_frame = 0
	_size = Vector2.ONE * (float(CELL) * radius / EDGE_RADIUS)
	_facing = -1.0 if facing < 0.0 else 1.0
	show()
	set_process(true)
	queue_redraw()

func clear() -> void:
	hide()
	set_process(false)

func _process(delta: float) -> void:
	_age += delta
	if _age >= FRAME_ENDS[-1]:
		clear()
		return
	var previous := _frame
	while _age >= FRAME_ENDS[_frame]:
		_frame += 1
	if previous != _frame:
		queue_redraw()

func _draw() -> void:
	var region := Rect2((_frame % 4) * CELL, floori(_frame / 4.0) * CELL, CELL, CELL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_facing, 1.0))
	draw_texture_rect_region(FLASH, Rect2(-_size * 0.5, _size), region)
