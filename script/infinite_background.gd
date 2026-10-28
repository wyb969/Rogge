extends Node2D
## Seamless infinite ground + sparse decorations that wrap around the camera.
## Covers any landscape aspect / zoom without Parallax repeat gaps.

@export var ground_texture: Texture2D
@export var decoration_texture: Texture2D
@export var tint: Color = Color(0.227451, 0.321569, 0.415686, 1.0)
@export var tile_size: float = 16.0
@export var cover_margin: float = 1.45
@export var decor_cell: float = 96.0
@export var decor_chance: float = 0.16

@onready var ground: Polygon2D = $GroundPoly
@onready var decor_root: Node2D = $DecorRoot

var _shader_mat: ShaderMaterial
var _decor_sprites: Array[Sprite2D] = []
var _decor_regions: Array[Rect2] = []

func _ready() -> void:
	z_index = -20
	_setup_ground()
	_setup_decor_pool()
	set_process(true)
	_update_coverage()

func _setup_ground() -> void:
	var shader := load("res://shaders/infinite_ground.gdshader") as Shader
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	_shader_mat.set_shader_parameter("ground_tex", ground_texture)
	_shader_mat.set_shader_parameter("atlas_tex_size", Vector2(128, 240))
	_shader_mat.set_shader_parameter("tile_pixel_size", Vector2(16, 16))
	_shader_mat.set_shader_parameter("base_tile_offset", Vector2(16, 16))
	_shader_mat.set_shader_parameter("variant_a_offset", Vector2(80, 0))
	_shader_mat.set_shader_parameter("variant_b_offset", Vector2(80, 16))
	_shader_mat.set_shader_parameter("world_tile_size", tile_size)
	_shader_mat.set_shader_parameter("tint", Vector4(tint.r, tint.g, tint.b, tint.a))
	ground.material = _shader_mat
	ground.z_index = -30
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _setup_decor_pool() -> void:
	_decor_regions = [
		Rect2(160, 32, 32, 32),
		Rect2(128, 64, 32, 32),
		Rect2(64, 64, 32, 32),
		Rect2(96, 96, 32, 32),
		Rect2(160, 128, 32, 32),
		Rect2(0, 32, 32, 32),
	]
	for i in 72:
		var spr := Sprite2D.new()
		spr.centered = true
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.visible = false
		spr.z_index = -10
		decor_root.add_child(spr)
		_decor_sprites.append(spr)

func _process(_delta: float) -> void:
	_update_coverage()

func _update_coverage() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null or ground == null:
		return

	var center := cam.get_screen_center_position()
	var vp := get_viewport().get_visible_rect().size
	var zoom := cam.zoom
	var half := Vector2(
		(vp.x / maxf(zoom.x, 0.001)) * 0.5 * cover_margin,
		(vp.y / maxf(zoom.y, 0.001)) * 0.5 * cover_margin
	)

	# Snap to tile grid so world-space UVs stay stable while following the camera.
	var snapped_center := Vector2(
		floor(center.x / tile_size) * tile_size,
		floor(center.y / tile_size) * tile_size
	)
	global_position = snapped_center

	ground.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])

	_update_decorations(center, half)

func _update_decorations(center: Vector2, half: Vector2) -> void:
	if decoration_texture == null or _decor_sprites.is_empty():
		return

	var min_c := Vector2i(
		int(floor((center.x - half.x) / decor_cell)),
		int(floor((center.y - half.y) / decor_cell))
	)
	var max_c := Vector2i(
		int(floor((center.x + half.x) / decor_cell)),
		int(floor((center.y + half.y) / decor_cell))
	)

	var idx := 0
	for cy in range(min_c.y, max_c.y + 1):
		for cx in range(min_c.x, max_c.x + 1):
			if idx >= _decor_sprites.size():
				break
			var h := _cell_hash(cx, cy)
			if (h % 1000) / 1000.0 > decor_chance:
				continue
			var spr := _decor_sprites[idx]
			idx += 1
			var region: Rect2 = _decor_regions[h % _decor_regions.size()]
			var atlas := AtlasTexture.new()
			atlas.atlas = decoration_texture
			atlas.region = region
			spr.texture = atlas
			var jitter := Vector2(
				float((h >> 3) % 40) - 20.0,
				float((h >> 7) % 40) - 20.0
			)
			spr.global_position = Vector2(float(cx) * decor_cell, float(cy) * decor_cell) + jitter
			spr.modulate = Color(0.78, 0.84, 0.72, 0.95)
			spr.scale = Vector2.ONE * (0.85 + float((h >> 11) % 40) / 100.0)
			spr.visible = true

	while idx < _decor_sprites.size():
		_decor_sprites[idx].visible = false
		idx += 1

func _cell_hash(x: int, y: int) -> int:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return abs(n)
