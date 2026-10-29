extends CenterContainer
## Centers a menu stack and sizes it from the live viewport.
## Portrait and landscape both stay on screen, including a mid-menu rotation.

@export var width_ratio: float = 0.78
@export var max_width: float = 440.0
@export var min_width: float = 220.0
@export var button_height_ratio: float = 0.085
@export var title_ratio: float = 0.07
@export var body_ratio: float = 0.04

var _box: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_apply_layout)
	if not get_viewport().size_changed.is_connected(_apply_layout):
		get_viewport().size_changed.connect(_apply_layout)
	for child in get_children():
		if child is VBoxContainer:
			_box = child
			break
	call_deferred("_apply_layout")

func _apply_layout() -> void:
	if _box == null or not is_instance_valid(_box):
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 8.0 or vp.y < 8.0:
		return
	var short_side := minf(vp.x, vp.y)
	var stack_w := clampf(vp.x * width_ratio, min_width, minf(max_width, vp.x - 28.0))
	var button_h := clampf(vp.y * button_height_ratio, 52.0, 88.0)
	var title_size := int(clampf(short_side * title_ratio, 26.0, 48.0))
	var body_size := int(clampf(short_side * body_ratio, 15.0, 22.0))
	var portrait := vp.y > vp.x
	_box.add_theme_constant_override("separation", 20 if portrait else 14)
	var saw_title := false
	for child in _box.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(stack_w, button_h)
			UiFonts.apply_to_button(child, body_size + 2)
		elif child is Label:
			child.custom_minimum_size.x = stack_w
			child.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var is_title := not saw_title
			saw_title = true
			UiFonts.apply_to_label(child, title_size if is_title else body_size, is_title)
