extends Button

func _ready() -> void:
	pivot_offset = size / 2
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	var tween = create_tween().set_parallel(true)
	if _supports_offset_transform():
		tween.tween_property(self, "offset_transform_scale", Vector2(1.15, 1.15), 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "offset_transform_rotation", deg_to_rad(3.0), 0.2)
	else:
		tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.2)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_mouse_exited() -> void:
	var tween = create_tween().set_parallel(true)
	if _supports_offset_transform():
		tween.tween_property(self, "offset_transform_scale", Vector2.ONE, 0.15)
		tween.tween_property(self, "offset_transform_rotation", 0.0, 0.15)
	else:
		tween.tween_property(self, "scale", Vector2.ONE, 0.15)

func _supports_offset_transform() -> bool:
	return "offset_transform_scale" in self
