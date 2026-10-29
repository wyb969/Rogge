extends CanvasLayer
## Left virtual joystick + right dash button for phone / web landscape play.

@onready var root: Control = $Root
@onready var stick_base: Control = $Root/JoystickBase
@onready var stick_knob: Control = $Root/JoystickBase/Knob
@onready var dash_button: Control = $Root/DashButton
@onready var dash_label: Label = $Root/DashButton/Label

@export var stick_radius: float = 56.0
@export var deadzone: float = 0.12

var _stick_touch_index: int = -1
var _dash_touch_index: int = -1
var _stick_center: Vector2 = Vector2.ZERO

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process_input(true)
	call_deferred("_layout_controls")
	get_viewport().size_changed.connect(_layout_controls)

func show_controls() -> void:
	if not _should_use_touch_ui():
		hide_controls()
		return
	visible = true
	MobileInput.controls_enabled = true
	MobileInput.clear_move()
	_layout_controls()

func hide_controls() -> void:
	visible = false
	MobileInput.controls_enabled = false
	MobileInput.clear_move()
	_reset_stick_visual()
	_set_dash_pressed_visual(false)

func _should_use_touch_ui() -> bool:
	if OS.has_feature("mobile"):
		return true
	if DisplayServer.is_touchscreen_available():
		return true
	# Web export on phones often reports as web; keep controls available.
	if OS.has_feature("web"):
		return true
	return false

func _layout_controls() -> void:
	if root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Left stick — bottom-left for landscape thumbs.
	var stick_size := stick_radius * 2.0
	stick_base.size = Vector2(stick_size, stick_size)
	stick_base.position = Vector2(28.0, vp.y - stick_size - 24.0)
	_stick_center = stick_base.size * 0.5
	stick_knob.size = Vector2(stick_radius, stick_radius)
	_reset_stick_visual()

	# Dash button — bottom-right.
	var dash_size := Vector2(92.0, 92.0)
	dash_button.size = dash_size
	dash_button.position = Vector2(vp.x - dash_size.x - 28.0, vp.y - dash_size.y - 28.0)
	if dash_label:
		dash_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _reset_stick_visual() -> void:
	if stick_knob == null:
		return
	stick_knob.position = _stick_center - stick_knob.size * 0.5
	stick_knob.modulate = Color(1, 1, 1, 0.85)

func _set_dash_pressed_visual(pressed: bool) -> void:
	if dash_button == null:
		return
	dash_button.modulate = Color(0.75, 1.0, 0.8, 1.0) if pressed else Color(1, 1, 1, 0.9)
	dash_button.scale = Vector2(0.92, 0.92) if pressed else Vector2.ONE
	dash_button.pivot_offset = dash_button.size * 0.5

func _input(event: InputEvent) -> void:
	if not visible or not MobileInput.controls_enabled:
		return

	if event is InputEventScreenTouch:
		if _handle_touch(event):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if _handle_drag(event):
			get_viewport().set_input_as_handled()
	# Desktop mouse fallback for quick browser testing without a phone.
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var fake := InputEventScreenTouch.new()
		fake.pressed = event.pressed
		fake.position = event.position
		fake.index = 0
		if _handle_touch(fake):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _stick_touch_index == 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = event.position
		if _handle_drag(drag):
			get_viewport().set_input_as_handled()

func _handle_touch(event: InputEventScreenTouch) -> bool:
	var pos: Vector2 = event.position
	if event.pressed:
		if _point_in_control(dash_button, pos) and _dash_touch_index < 0:
			_dash_touch_index = event.index
			_set_dash_pressed_visual(true)
			MobileInput.request_dash()
			return true
		if _stick_touch_index < 0 and (_point_in_control(stick_base, pos) or _near_stick_zone(pos)):
			_stick_touch_index = event.index
			_update_stick(pos)
			return true
		return false
	else:
		var handled := false
		if event.index == _stick_touch_index:
			_stick_touch_index = -1
			MobileInput.clear_move()
			_reset_stick_visual()
			handled = true
		if event.index == _dash_touch_index:
			_dash_touch_index = -1
			_set_dash_pressed_visual(false)
			handled = true
		return handled

func _handle_drag(event: InputEventScreenDrag) -> bool:
	if event.index == _stick_touch_index:
		_update_stick(event.position)
		return true
	return false

func _near_stick_zone(pos: Vector2) -> bool:
	# Generous grab area so left-thumb presses near the stick still latch.
	var center := stick_base.global_position + stick_base.size * 0.5
	return pos.distance_to(center) <= stick_radius * 2.4

func _point_in_control(ctrl: Control, pos: Vector2) -> bool:
	if ctrl == null:
		return false
	var r := Rect2(ctrl.global_position, ctrl.size)
	return r.has_point(pos)

func _update_stick(screen_pos: Vector2) -> void:
	var center := stick_base.global_position + stick_base.size * 0.5
	var offset := screen_pos - center
	if offset.length() > stick_radius:
		offset = offset.normalized() * stick_radius
	stick_knob.position = (_stick_center + offset) - stick_knob.size * 0.5

	var strength := offset.length() / stick_radius
	if strength < deadzone:
		MobileInput.clear_move()
		return
	var remapped := (strength - deadzone) / (1.0 - deadzone)
	MobileInput.set_move_vector(offset.normalized() * remapped)
