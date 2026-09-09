extends Button

func _ready() -> void:
	# 设置缩放中心点为按钮正中央（非常重要，保证从中心放大）
	pivot_offset = size / 2

	# 连接鼠标进入和离开信号
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	# 创建 Tween 动画，直接对 4.7 新增的 offset_transform_scale 和 offset_transform_rotation 补间
	var tween = create_tween().set_parallel(true)

	# 放大到 1.15 倍，带有弹性效果 (EASE_OUT + TRANS_BACK)
	tween.tween_property(self, "offset_transform_scale", Vector2(1.15, 1.15), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 稍微倾斜 3 度，增加 Q 弹感
	tween.tween_property(self, "offset_transform_rotation", deg_to_rad(3.0), 0.2)

func _on_mouse_exited() -> void:
	var tween = create_tween().set_parallel(true)

	# 恢复原状
	tween.tween_property(self, "offset_transform_scale", Vector2.ONE, 0.15)
	tween.tween_property(self, "offset_transform_rotation", 0.0, 0.15)
