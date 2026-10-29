extends TextureRect
## Feeds the menu pattern the live width/height so tiles stay square
## in portrait and landscape.

func _ready() -> void:
	if material is ShaderMaterial:
		material = (material as ShaderMaterial).duplicate()
	if not resized.is_connected(_apply_aspect):
		resized.connect(_apply_aspect)
	_apply_aspect()
	call_deferred("_apply_aspect")

func _apply_aspect() -> void:
	var mat := material as ShaderMaterial
	if mat == null or size.y < 1.0:
		return
	mat.set_shader_parameter("g_aspect", size.x / size.y)
