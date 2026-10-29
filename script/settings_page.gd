extends CanvasLayer
## Title-screen settings. Volume, on-screen control layout, and a difficulty
## choice that is saved but does not change combat yet.

signal closed

const SIZE_MIN := 0.7
const SIZE_MAX := 1.6

var volume_slider: HSlider
var size_slider: HSlider
var opacity_slider: HSlider
const DIFF_LABELS: PackedStringArray = ["简单  Easy", "中等  Medium", "困难  Hard"]

var difficulty_button: Button
var difficulty_list: VBoxContainer
var volume_value: Label
var back_button: Button
var hint_label: Label
var _panel: PanelContainer
var _scroll: ScrollContainer
var _box: VBoxContainer
var _base_left: float
var _base_right: float
var _base_top: float
var _base_bottom: float
var _follow: Vector2 = Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 70
	visible = false
	_build_ui()
	if not get_viewport().size_changed.is_connected(_fit):
		get_viewport().size_changed.connect(_fit)
	call_deferred("_fit")

func _process(delta: float) -> void:
	if not visible or _panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var target := Vector2.ZERO
	if vp.x > 1.0 and vp.y > 1.0:
		var mouse := get_viewport().get_mouse_position()
		target = Vector2(
			clampf(mouse.x / vp.x - 0.5, -0.5, 0.5) * 14.0,
			clampf(mouse.y / vp.y - 0.5, -0.5, 0.5) * 8.0
		)
	var blend := clampf(1.0 - exp(-12.0 * delta), 0.0, 1.0)
	_follow = _follow.lerp(target, blend)
	_panel.offset_left = _base_left + _follow.x
	_panel.offset_right = _base_right + _follow.x
	_panel.offset_top = _base_top + _follow.y
	_panel.offset_bottom = _base_bottom + _follow.y

func open_page() -> void:
	visible = true
	_sync_from_store()
	_fit()

func close_page() -> void:
	visible = false
	closed.emit()

func _sync_from_store() -> void:
	if volume_slider:
		volume_slider.set_value_no_signal(SettingsStore.master_linear)
		_refresh_volume_label()
	if size_slider:
		size_slider.set_value_no_signal(SettingsStore.control_scale)
	if opacity_slider:
		opacity_slider.set_value_no_signal(SettingsStore.control_opacity)
	if difficulty_button:
		difficulty_button.text = _difficulty_caption(SettingsStore.difficulty)

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.07, 0.12, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.17, 0.19, 0.96)
	panel_style.border_color = Color(0.72, 0.84, 0.92, 0.4)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.shadow_color = Color(0.25, 0.55, 0.9, 0.35)
	panel_style.shadow_size = 18
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_top = 14.0
	panel_style.content_margin_bottom = 14.0
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(outer)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_scroll)

	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_box)

	_box.add_child(_label("设置  Settings", 28, true))
	_box.add_child(_label("音量  Volume", 16, false))
	volume_slider = _slider(0.0, 1.0, 0.01)
	volume_slider.value_changed.connect(_on_volume)
	volume_slider.drag_ended.connect(_on_volume_released)
	_box.add_child(volume_slider)
	volume_value = _label("100%", 14, false)
	_box.add_child(volume_value)

	_box.add_child(_label("按键大小  Button size", 16, false))
	size_slider = _slider(SIZE_MIN, SIZE_MAX, 0.05)
	size_slider.value_changed.connect(_on_size)
	_box.add_child(size_slider)

	_box.add_child(_label("透明度  Opacity", 16, false))
	opacity_slider = _slider(0.25, 1.0, 0.05)
	opacity_slider.value_changed.connect(_on_opacity)
	_box.add_child(opacity_slider)

	_box.add_child(_label("难度  Difficulty", 16, false))
	difficulty_button = Button.new()
	difficulty_button.name = "DifficultyPicker"
	difficulty_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	difficulty_button.custom_minimum_size = Vector2(0, 48)
	difficulty_button.pressed.connect(_toggle_difficulty_list)
	_style_action(difficulty_button)
	_box.add_child(difficulty_button)
	difficulty_list = VBoxContainer.new()
	difficulty_list.name = "DifficultyList"
	difficulty_list.visible = false
	difficulty_list.add_theme_constant_override("separation", 4)
	_box.add_child(difficulty_list)
	for index in DIFF_LABELS.size():
		var choice := Button.new()
		choice.custom_minimum_size = Vector2(0, 44)
		choice.pressed.connect(_on_difficulty_choice.bind(index))
		choice.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style_action(choice)
		# Label uses the same font path as the rest of the panel. Button.text on a
		# web popup was shaping without the CJK fallback.
		var caption := _label(DIFF_LABELS[index], 18, false)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.set_anchors_preset(Control.PRESET_FULL_RECT)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		choice.add_child(caption)
		difficulty_list.add_child(choice)

	hint_label = _label("拖动摇杆和冲刺键   Drag stick and DASH", 14, false)
	outer.add_child(hint_label)

	back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = "返回  Back"
	back_button.custom_minimum_size = Vector2(0, 52)
	_style_action(back_button)
	back_button.pressed.connect(close_page)
	outer.add_child(back_button)
	_sync_from_store()

func _difficulty_caption(index: int) -> String:
	var safe := clampi(index, 0, DIFF_LABELS.size() - 1)
	return "%s  v" % DIFF_LABELS[safe]

func _toggle_difficulty_list() -> void:
	if difficulty_list:
		difficulty_list.visible = not difficulty_list.visible

func _on_difficulty_choice(index: int) -> void:
	_on_difficulty(index)
	if difficulty_button:
		difficulty_button.text = _difficulty_caption(index)
	if difficulty_list:
		difficulty_list.visible = false

func _style_action(button: Button) -> void:
	button.set_meta("juicy_glow", true)
	button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.97, 1.0))
	UiFonts.apply_to_button(button, 18)
	JuicyHover.bind(button)

func _label(text: String, size: int, bold: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	UiFonts.apply_to_label(label, size, bold)
	return label

func _slider(min_v: float, max_v: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.custom_minimum_size = Vector2(0, 40)
	JuicyHover.bind(slider)
	return slider

func _on_volume(value: float) -> void:
	SettingsStore.set_master_linear(value)
	_refresh_volume_label()

func _on_volume_released(_changed: bool) -> void:
	if AudioManager and AudioManager.has_method("play_pickup"):
		AudioManager.play_pickup()

func _refresh_volume_label() -> void:
	if volume_value:
		volume_value.text = "%d%%" % int(round(SettingsStore.master_linear * 100.0))

func _on_size(value: float) -> void:
	SettingsStore.set_control_scale(value)
	_notify_controls()

func _on_opacity(value: float) -> void:
	SettingsStore.set_control_opacity(value)
	_notify_controls()

func _on_difficulty(index: int) -> void:
	SettingsStore.set_difficulty(index)
	if AudioManager and AudioManager.has_method("play_upgrade"):
		AudioManager.play_upgrade()

func _notify_controls() -> void:
	var controls := get_parent().get_node_or_null("MobileControls") if get_parent() else null
	if controls and controls.has_method("apply_saved_layout"):
		controls.apply_saved_layout()

func _fit() -> void:
	if _panel == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 8.0 or vp.y < 8.0:
		return
	var width := clampf(vp.x * 0.88, 240.0, 460.0)
	var height := minf(vp.y - 80.0, 620.0)
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_base_left = -width * 0.5
	_base_right = width * 0.5
	_base_top = 64.0
	_base_bottom = 64.0 + height
	_panel.offset_left = _base_left + _follow.x
	_panel.offset_right = _base_right + _follow.x
	_panel.offset_top = _base_top + _follow.y
	_panel.offset_bottom = _base_bottom + _follow.y
	for child in _box.get_children():
		if child is Control:
			child.custom_minimum_size.x = maxf(160.0, width - 48.0)
	if back_button:
		back_button.custom_minimum_size.x = maxf(160.0, width - 48.0)
	if hint_label:
		hint_label.custom_minimum_size.x = maxf(160.0, width - 48.0)
	if difficulty_list:
		for choice in difficulty_list.get_children():
			if choice is Control:
				choice.custom_minimum_size.x = maxf(160.0, width - 48.0)
