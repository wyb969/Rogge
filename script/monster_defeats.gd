extends Node2D

# Retire the combat actor immediately. Only these reusable body images linger.
const CAPACITY := 24
const FRAME_TIME := 1.0 / 8.0
var sprites: Array[Sprite2D] = []
var ages := PackedFloat32Array()
var next := 0

func _ready() -> void:
	z_as_relative = false
	z_index = -1
	process_mode = Node.PROCESS_MODE_PAUSABLE
	ages.resize(CAPACITY)
	for i in CAPACITY:
		var sprite := Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.hide()
		add_child(sprite)
		sprites.append(sprite)
	set_process(false)

func capture(source: Sprite2D, first_column: int) -> void:
	var sprite := sprites[next]
	sprite.texture = source.texture
	sprite.hframes = source.hframes
	sprite.vframes = source.vframes
	sprite.frame_coords = Vector2i(first_column, source.frame_coords.y)
	sprite.flip_h = source.flip_h
	sprite.global_transform = source.global_transform
	sprite.self_modulate = Color.WHITE
	sprite.show()
	ages[next] = 0
	next = (next + 1) % CAPACITY
	set_process(true)

func _process(delta: float) -> void:
	var active := false
	for i in CAPACITY:
		var sprite := sprites[i]
		if not sprite.visible: continue
		ages[i] += delta
		if ages[i] >= 4 * FRAME_TIME:
			sprite.hide()
			continue
		var cell := sprite.frame_coords
		cell.x = cell.x - cell.x % 4 + floori(ages[i] / FRAME_TIME)
		sprite.frame_coords = cell
		sprite.self_modulate.a = minf(1.0, (4 * FRAME_TIME - ages[i]) / FRAME_TIME)
		active = true
	set_process(active)

func reset() -> void:
	for sprite in sprites: sprite.hide()
	next = 0
	set_process(false)
