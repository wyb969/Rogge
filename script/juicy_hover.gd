class_name JuicyHover
extends RefCounted
## Hover, press, and cursor feedback. Touch still activates the control.

static func bind(control: Control) -> void:
	if control == null:
		return
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.pivot_offset = control.size * 0.5
	if not control.resized.is_connected(_sync_pivot.bind(control)):
		control.resized.connect(_sync_pivot.bind(control))
	if not control.mouse_entered.is_connected(_on_enter.bind(control)):
		control.mouse_entered.connect(_on_enter.bind(control))
	if not control.mouse_exited.is_connected(_on_exit.bind(control)):
		control.mouse_exited.connect(_on_exit.bind(control))
	if not control.gui_input.is_connected(_on_gui.bind(control)):
		control.gui_input.connect(_on_gui.bind(control))

static func _sync_pivot(control: Control) -> void:
	if is_instance_valid(control):
		control.pivot_offset = control.size * 0.5

static func _on_enter(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var hover_scale := 1.03 if control is HSlider else 1.05
	_tween_scale(control, Vector2(hover_scale, hover_scale))
	control.modulate = Color(1.14, 1.22, 1.08, 1)
	if control.get_meta("juicy_glow", false) and control is Button:
		_apply_glow(control, false)

static func _on_exit(control: Control) -> void:
	if not is_instance_valid(control):
		return
	_tween_scale(control, Vector2.ONE)
	control.modulate = Color.WHITE
	control.rotation = 0.0
	if control is Button:
		control.remove_theme_stylebox_override("hover")
		control.remove_theme_stylebox_override("pressed")

static func _on_gui(event: InputEvent, control: Control) -> void:
	if not is_instance_valid(control):
		return
	if event is InputEventMouseMotion:
		_follow_pointer(control, event.position)
		return
	var pressed := false
	var is_button := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		is_button = true
	elif event is InputEventScreenTouch:
		pressed = event.pressed
		is_button = true
	if not is_button:
		return
	var hover_scale := 1.03 if control is HSlider else 1.05
	_tween_scale(control, Vector2(0.96, 0.96) if pressed else Vector2(hover_scale, hover_scale))
	if control.get_meta("juicy_glow", false) and control is Button:
		_apply_glow(control, pressed)

static func _follow_pointer(control: Control, _screen_pos: Vector2) -> void:
	var local := control.get_local_mouse_position()
	var nx := clampf(local.x / maxf(control.size.x, 1.0), 0.0, 1.0)
	var ny := clampf(local.y / maxf(control.size.y, 1.0), 0.0, 1.0)
	control.modulate = Color(1.06 + nx * 0.14, 1.1 + (1.0 - ny) * 0.12, 1.04, 1.0)
	if control is Button:
		control.rotation = (nx - 0.5) * 0.07
		control.pivot_offset = control.size * 0.5

static func _tween_scale(control: Control, target: Vector2) -> void:
	if control.has_meta("juicy_tween"):
		var old: Variant = control.get_meta("juicy_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tween := control.create_tween()
	control.set_meta("juicy_tween", tween)
	tween.tween_property(control, "scale", target, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func _apply_glow(control: Button, pressed: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.12, 0.2, 0.28, 1.0) if pressed else Color(0.2, 0.36, 0.46, 0.98)
	box.set_border_width_all(2)
	box.border_color = Color(0.62, 0.95, 1.0, 0.9)
	box.set_corner_radius_all(10)
	box.shadow_color = Color(0.35, 0.78, 1.0, 0.4 if pressed else 0.7)
	box.shadow_size = 6 if pressed else 16
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	control.add_theme_stylebox_override("hover", box)
	control.add_theme_stylebox_override("pressed", box)
