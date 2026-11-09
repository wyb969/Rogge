extends Node2D

const MAX_FLASHES := 48
const FLASH_SECONDS := 0.34
const BURN := 1
const POISON := 2
const BURN_COLOR := GamePalette.FRIENDLY_BLUE
const POISON_COLOR := GamePalette.POISON_PURPLE
var _records: Array[Dictionary] = []
var _indices: Dictionary = {}
var _slot := 0
var _redraw_left := 0.0
var flashes := 0

func _ready() -> void:
	z_as_relative = false
	z_index = 14
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shared := ShaderMaterial.new()
	shared.shader = preload("res://shaders/status_echo_flash.gdshader")
	shared.set_shader_parameter("ink_color", GamePalette.INK)
	material = shared
	for _i in MAX_FLASHES:
		_records.append({"actor": null, "sprite": null, "id": 0, "left": 0.0, "kind": 0})
	set_process(false)

static func color_for(kind: int, age: float) -> Color:
	if kind == (BURN | POISON):
		return BURN_COLOR.lerp(POISON_COLOR, smoothstep(0.09, 0.23, age))
	return POISON_COLOR if (kind & POISON) != 0 else BURN_COLOR

func flash(target: WeakRef, kind: int) -> void:
	var actor: Node2D = target.get_ref()
	if kind == 0 or not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup"): return
	var sprite := actor.get("sprite_2d") as Sprite2D
	if not is_instance_valid(sprite) or sprite.texture == null: return
	var id := actor.get_instance_id()
	var index: int = _indices.get(id, _slot)
	var record: Dictionary = _records[index]
	if record.id != id:
		_indices.erase(record.id)
		_slot = (_slot + 1) % MAX_FLASHES
	_indices[id] = index
	record.actor = target
	record.sprite = sprite
	record.id = id
	record.left = FLASH_SECONDS
	record.kind = kind
	flashes += 1
	if not is_processing():
		_redraw_left = 0.0
		queue_redraw()
	set_process(true)

func reset() -> void:
	for record in _records:
		record.actor = null
		record.sprite = null
		record.id = 0
		record.left = 0.0
		record.kind = 0
	_indices.clear()
	_slot = 0
	_redraw_left = 0.0
	flashes = 0
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	if get_tree().paused: return
	var active := false
	for record in _records:
		if record.left <= 0.0: continue
		var actor: Node2D = record.actor.get_ref()
		record.left = maxf(0.0, record.left - delta)
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup") or not is_instance_valid(record.sprite):
			record.left = 0.0
		if record.left <= 0.0:
			_indices.erase(record.id)
			record.actor = null
			record.sprite = null
			record.id = 0
		else: active = true
	_redraw_left -= delta
	if _redraw_left <= 0.0 or not active:
		_redraw_left = 1.0 / 30.0
		queue_redraw()
	if not active: set_process(false)

func _draw() -> void:
	var inverse := global_transform.affine_inverse()
	for record in _records:
		if record.left <= 0.0: continue
		var actor: Node2D = record.actor.get_ref()
		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or not actor.is_in_group("EnemyGroup") or not is_instance_valid(record.sprite): continue
		var sprite: Sprite2D = record.sprite
		if not sprite.is_visible_in_tree() or sprite.texture == null: continue
		var region := sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, sprite.texture.get_size())
		var cell := region.size / Vector2(sprite.hframes, sprite.vframes)
		var source := Rect2(region.position + Vector2(sprite.frame_coords) * cell, cell)
		var transform := inverse * sprite.global_transform
		transform = transform.scaled_local(Vector2(-1.0 if sprite.flip_h else 1.0, -1.0 if sprite.flip_v else 1.0))
		draw_set_transform_matrix(transform)
		var tint := color_for(record.kind, FLASH_SECONDS - float(record.left))
		tint.a = 0.94 * clampf(float(record.left) / 0.14, 0.0, 1.0) * sprite.modulate.a * sprite.self_modulate.a
		draw_texture_rect_region(sprite.texture, sprite.get_rect(), source, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)
