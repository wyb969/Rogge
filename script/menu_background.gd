extends TextureRect



func _ready() -> void :
	if material is ShaderMaterial:
		material = (material as ShaderMaterial).duplicate()
		material.set_shader_parameter("g_color_a", GamePalette.alpha(GamePalette.UI_BORDER,0))
		material.set_shader_parameter("g_color_b", GamePalette.alpha(GamePalette.UI_BORDER,0.15))
	if get_parent() is ColorRect: get_parent().color = GamePalette.UI_PANEL
	if not resized.is_connected(_apply_aspect):
		resized.connect(_apply_aspect)
	_apply_aspect()
	call_deferred("_apply_aspect")

func _apply_aspect() -> void :
	var mat: = material as ShaderMaterial
	if mat == null or size.y < 1.0:
		return
	mat.set_shader_parameter("g_aspect", size.x / size.y)
