extends CanvasLayer
## Left virtual joystick + right dash button for phone / web play.
## Settings can scale, fade, and drag them. Positions are saved as viewport fractions.

const BASE_STICK_RADIUS := 56.0
const BASE_DASH_SIZE := 92.0
const LAYOUT_MARGIN := 8.0

@onready var root: Control = $Root
@onready var stick_base: Control = $Root/JoystickBase
@onready var stick_knob: Control = $Root/JoystickBase/Knob
@onready var dash_button: Control = $Root/DashButton
@onready var dash_label: Label = $Root/DashButton/Label

@export var stick_radius: float = 56.0
@export var deadzone: float = 0.12

var layout_edit: bool = false
var _opacity: float = 0.85
var _drag_target: String = ""
var _drag_offset: Vector2 = Vector2.ZERO
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

func _process(delta: float) -> void:
	if not layout_edit or not visible:
		return
	var mouse := get_viewport().get_mouse_position()
	var blend := clampf(1.0 - exp(-16.0 * delta), 0.0, 1.0)
	_juice_layout_widget(stick_base, mouse, _drag_target == "stick", blend)
	_juice_layout_widget(dash_button, mouse, _drag_target == "dash", blend)

func show_controls() -> void:
	layout_edit = false
	_drag_target = ""
	_set_edit_cursor(false)
	_reset_widget_juice()
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
	_reset_widget_juice()

func begin_layout_edit() -> void:
	layout_edit = true
	visible = true
	MobileInput.controls_enabled = false
	MobileInput.clear_move()
	_stick_touch_index = -1
	_dash_touch_index = -1
	_drag_target = ""
	_set_edit_cursor(true)
	_layout_controls()

func end_layout_edit() -> void:
	if _drag_target != "":
		commit_layout_from_positions()
		_drag_target = ""
	layout_edit = false
	_set_edit_cursor(false)
	_reset_widget_juice()
	hide_controls()

func apply_saved_layout() -> void:
	_layout_controls()

func commit_layout_from_positions() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 1.0 or vp.y < 1.0:
		return
	var stick_center := stick_base.global_position + stick_base.size * 0.5
	var dash_center := dash_button.global_position + dash_button.size * 0.5
	SettingsStore.set_stick_norm(_norm_from_center(stick_center, vp))
	SettingsStore.set_dash_norm(_norm_from_center(dash_center, vp))

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
	_apply_metrics(vp)
	if _drag_target == "":
		_place_stick(vp)
		_place_dash(vp)
	else:
		stick_base.position = _clamp_top_left(stick_base.position, stick_base.size, vp)
		dash_button.position = _clamp_top_left(dash_button.position, dash_button.size, vp)
	_stick_center = stick_base.size * 0.5
	_reset_stick_visual()

func _apply_metrics(vp: Vector2) -> void:
	var scale := 1.0
	_opacity = 0.85
	if SettingsStore:
		scale = SettingsStore.control_scale
		_opacity = SettingsStore.control_opacity
	stick_radius = BASE_STICK_RADIUS * scale
	var stick_size := Vector2.ONE * stick_radius * 2.0
	var dash_size := Vector2.ONE * BASE_DASH_SIZE * scale
	_resize_keeping_center(stick_base, stick_size, vp)
	_resize_keeping_center(dash_button, dash_size, vp)
	stick_knob.size = Vector2(stick_radius, stick_radius)
	stick_base.modulate = Color(1, 1, 1, _opacity)
	dash_button.modulate = Color(1, 1, 1, _opacity)
	if dash_label:
		dash_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _place_stick(vp: Vector2) -> void:
	var top_left := Vector2(28.0, vp.y - stick_base.size.y - 24.0)
	if SettingsStore and SettingsStore.has_custom_stick():
		var center := SettingsStore.stick_norm * vp
		top_left = center - stick_base.size * 0.5
	stick_base.global_position = _clamp_top_left(top_left, stick_base.size, vp)

func _place_dash(vp: Vector2) -> void:
	var top_left := Vector2(vp.x - dash_button.size.x - 28.0, vp.y - dash_button.size.y - 28.0)
	if SettingsStore and SettingsStore.has_custom_dash():
		var center := SettingsStore.dash_norm * vp
		top_left = center - dash_button.size * 0.5
	dash_button.global_position = _clamp_top_left(top_left, dash_button.size, vp)

func _resize_keeping_center(ctrl: Control, new_size: Vector2, vp: Vector2) -> void:
	var center := ctrl.position + ctrl.size * 0.5
	if ctrl.size.x < 2.0:
		center = new_size * 0.5
	ctrl.size = new_size
	ctrl.position = _clamp_top_left(center - new_size * 0.5, new_size, vp)
	ctrl.pivot_offset = new_size * 0.5

func _clamp_top_left(pos: Vector2, size: Vector2, vp: Vector2) -> Vector2:
	var max_x := maxf(LAYOUT_MARGIN, vp.x - size.x - LAYOUT_MARGIN)
	var max_y := maxf(LAYOUT_MARGIN, vp.y - size.y - LAYOUT_MARGIN)
	return Vector2(clampf(pos.x, LAYOUT_MARGIN, max_x), clampf(pos.y, LAYOUT_MARGIN, max_y))

func _norm_from_center(center: Vector2, vp: Vector2) -> Vector2:
	return Vector2(
		clampf(center.x / vp.x, 0.0, 1.0),
		clampf(center.y / vp.y, 0.0, 1.0)
	)

func _set_edit_cursor(editing: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if editing else Control.MOUSE_FILTER_IGNORE
	var cursor := Control.CURSOR_POINTING_HAND if editing else Control.CURSOR_ARROW
	for ctrl in [stick_base, dash_button]:
		if ctrl == null:
			continue
		ctrl.mouse_filter = filter
		ctrl.mouse_default_cursor_shape = cursor

func _reset_widget_juice() -> void:
	for ctrl in [stick_base, dash_button]:
		if ctrl == null:
			continue
		ctrl.scale = Vector2.ONE
		ctrl.rotation = 0.0

func _juice_layout_widget(ctrl: Control, mouse: Vector2, dragging: bool, blend: float) -> void:
	if ctrl == null:
		return
	var hot := dragging or _point_in_control(ctrl, mouse)
	var target_scale := Vector2(1.08, 1.08) if dragging else (Vector2(1.05, 1.05) if hot else Vector2.ONE)
	ctrl.pivot_offset = ctrl.size * 0.5
	ctrl.scale = ctrl.scale.lerp(target_scale, blend)
	var tint := Color(1.18, 1.32, 1.12, _opacity) if hot else Color(1, 1, 1, _opacity)
	ctrl.modulate = ctrl.modulate.lerp(tint, blend)

func _reset_stick_visual() -> void:
	if stick_knob == null:
		return
	stick_knob.position = _stick_center - stick_knob.size * 0.5
	stick_knob.modulate = Color.WHITE

func _set_dash_pressed_visual(pressed: bool) -> void:
	if dash_button == null:
		return
	var color := Color(0.75, 1.0, 0.8, _opacity) if pressed else Color(1, 1, 1, _opacity)
	dash_button.modulate = color
	dash_button.scale = Vector2(0.92, 0.92) if pressed else Vector2.ONE
	dash_button.pivot_offset = dash_button.size * 0.5

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if layout_edit:
		if _handle_layout_pointer(event):
			get_viewport().set_input_as_handled()
		return
	if not MobileInput.controls_enabled:
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

func _handle_layout_pointer(event: InputEvent) -> bool:
	var pos := Vector2.ZERO
	var kind := ""
	if event is InputEventScreenTouch:
		pos = event.position
		kind = "press" if event.pressed else "release"
	elif event is InputEventScreenDrag:
		pos = event.position
		kind = "drag"
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		kind = "press" if event.pressed else "release"
	elif event is InputEventMouseMotion and _drag_target != "" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		pos = event.position
		kind = "drag"
	else:
		return false

	if kind == "press":
		if _point_in_control(dash_button, pos):
			_drag_target = "dash"
			_drag_offset = dash_button.global_position - pos
			return true
		if _point_in_control(stick_base, pos) or _near_stick_zone(pos):
			_drag_target = "stick"
			_drag_offset = stick_base.global_position - pos
			return true
		return false
	if _drag_target == "":
		return false
	var vp := get_viewport().get_visible_rect().size
	var ctrl := stick_base if _drag_target == "stick" else dash_button
	ctrl.global_position = _clamp_top_left(pos + _drag_offset, ctrl.size, vp)
	if kind == "release":
		commit_layout_from_positions()
		_drag_target = ""
	return true

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
	return ctrl.get_global_rect().has_point(pos)

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
