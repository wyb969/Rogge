extends Control

# Only recent interactive tests live here. Older presets remain callable by smoke tests.
const RECENT_ORDER: Array[String] = [
	"DebugEquipmentCombosButton", "DebugGrowthButton", "DebugArsenalButton",
	"DebugBomb5Button", "DebugBombButton", "DebugFanStatusButton",
	"DebugControlCardsButton", "DebugFan5Button", "DebugFanButton",
	"DebugBlackHole5Button", "DebugBlackHoleButton", "DebugCritical5Button", "DebugCriticalButton",
]
const DEFAULT_HINT: = "近期测试 · 下方按钮翻页"

@onready var box: Control = $VBoxContainer
@onready var title: Label = $VBoxContainer/TitleLabel
@onready var hint: Label = $VBoxContainer/DebugHint
@onready var back_button: Button = $VBoxContainer/BackButton
@onready var report_button: Button = $VBoxContainer/DebugReportButton
var prev_button: Button
var next_button: Button
var page_label: Label
var panel: Panel
var entries: Array[Button] = []
var page_index: = 0
var page_size: = 4
var page_count: = 1
var columns: = 1
var _fit_pending: = false
var _ui: = 1.0
var _button_height: = 48.0
var _gap: = 8.0
var _body_origin: = Vector2.ZERO
var _body_width: = 0.0
var _styles: Dictionary = {}

func _ready() -> void:
	_build_styles()
	panel = Panel.new()
	panel.name = "DebugPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _styles.panel)
	add_child(panel)
	move_child(panel, 0)
	for entry_name in RECENT_ORDER:
		var button: Button = box.get_node_or_null(entry_name)
		if button != null:
			entries.append(button)
	for button in entries + [back_button, report_button]:
		_prepare_button(button)
	prev_button = _new_button("PreviousPage", "上一页", -1)
	next_button = _new_button("NextPage", "下一页", 1)
	page_label = Label.new()
	page_label.name = "PageIndicator"
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(page_label)
	for label in [title, hint, page_label]:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.custom_minimum_size = Vector2.ZERO
	title.text = "Debug · 近期测试"
	hint.text = DEFAULT_HINT
	back_button.text = "返回主页"
	report_button.text = "导出诊断"
	get_viewport().size_changed.connect(_request_fit)
	_request_fit()

func _style(color: Color, border: Color) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

func _build_styles() -> void:
	_styles.normal = _style(Color("20343e"), Color("46636d"))
	_styles.hover = _style(Color("2e5058"), Color("77c6b0"))
	_styles.pressed = _style(Color("397d70"), Color("b1eed2"))
	_styles.disabled = _style(Color("202b32"), Color("35444c"))
	var focus: = _style(Color.TRANSPARENT, Color("b1eed2"))
	focus.draw_center = false
	_styles.focus = focus
	_styles.panel = _style(Color(0.045, 0.08, 0.11, 0.97), Color("46636d"))

func _prepare_button(button: Button) -> void:
	button.custom_minimum_size = Vector2.ZERO
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = button.text
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, _styles[state])
	button.add_theme_color_override("font_color", Color("ecf5ed"))
	button.add_theme_color_override("font_disabled_color", Color("6b7e85"))

func _new_button(node_name: String, text: String, direction: int) -> Button:
	var button: = Button.new()
	button.name = node_name
	button.text = text
	box.add_child(button)
	_prepare_button(button)
	button.pressed.connect(change_page.bind(direction))
	return button

func _request_fit() -> void:
	if _fit_pending:
		return
	_fit_pending = true
	call_deferred("_fit")

func _display_pixel_ratio() -> float:
	if OS.has_feature("web"):
		# Web canvases use device pixels; touch targets are measured in CSS pixels.
		var css_width: Variant = JavaScriptBridge.eval("(function(){var c=document.getElementById('canvas');return c?c.getBoundingClientRect().width:window.innerWidth;})()", true)
		if (css_width is float or css_width is int) and float(css_width) > 0.0:
			return float(get_tree().root.size.x) / float(css_width)
	return 1.0

func _fit() -> void:
	_fit_pending = false
	var vp: = get_viewport().get_visible_rect().size
	# The logical viewport is often 900 px wide even on a 390 px phone.
	var transform: = get_viewport().get_final_transform()
	var physical_scale: = (transform * Vector2.RIGHT - transform * Vector2.ZERO).length()
	_ui = _display_pixel_ratio() / maxf(physical_scale, 0.1)
	var physical_height: = vp.y / _ui
	var compact: = physical_height < 520.0
	var tiny: = physical_height < 340.0
	var padding: = (10.0 if compact else 14.0) * _ui
	_gap = 8.0 * _ui
	_button_height = 48.0 * _ui
	var title_height: = (24.0 if compact else 34.0) * _ui
	var title_gap: = (6.0 if compact else 12.0) * _ui
	var page_gap: = (6.0 if compact else 12.0) * _ui
	var utility_gap: = 6.0 * _ui
	var hint_gap: = (0.0 if tiny else 4.0) * _ui
	var hint_height: = (0.0 if tiny else 16.0) * _ui
	var footer_height: = 44.0 * _ui
	var safe_top: = 44.0 * _ui
	var safe_bottom: = 8.0 * _ui
	var width: = maxf(80.0 * _ui, minf(620.0 * _ui, vp.x - 24.0 * _ui))
	_body_width = width - padding * 2.0
	columns = 2 if _body_width / _ui >= 500.0 else 1
	var fixed_height: = padding * 2.0 + title_height + title_gap + page_gap + footer_height * 2.0 + utility_gap + hint_gap + hint_height
	var available: = vp.y - safe_top - safe_bottom
	var rows: = clampi(int(floor((available - fixed_height + _gap) / (_button_height + _gap))), 1, 3 if columns == 2 else 4)
	var anchor: = page_index * page_size
	page_size = rows * columns
	page_count = maxi(1, ceili(float(entries.size()) / page_size))
	@warning_ignore("integer_division")
	page_index = clampi(anchor / page_size, 0, page_count - 1)
	var body_height: = rows * _button_height + (rows - 1) * _gap
	var height: = fixed_height + body_height
	panel.position = Vector2((vp.x - width) * 0.5, safe_top + maxf(0.0, (available - height) * 0.5))
	panel.size = Vector2(width, height)
	box.position = Vector2.ZERO
	box.size = vp
	var origin: = panel.position + Vector2.ONE * padding
	UiFonts.apply_to_label(title, int((20 if compact else 24) * _ui), true)
	title.position = origin
	title.size = Vector2(_body_width, title_height)
	_body_origin = origin + Vector2(0, title_height + title_gap)
	var pager_y: = _body_origin.y + body_height + page_gap
	var pager_width: = minf(112.0 * _ui, (_body_width - 64.0 * _ui - _gap * 2.0) * 0.5)
	for button in [prev_button, next_button, back_button, report_button]:
		UiFonts.apply_to_button(button, int(16 * _ui))
	prev_button.position = Vector2(origin.x, pager_y)
	prev_button.size = Vector2(pager_width, footer_height)
	next_button.position = Vector2(origin.x + _body_width - pager_width, pager_y)
	next_button.size = Vector2(pager_width, footer_height)
	UiFonts.apply_to_label(page_label, int(14 * _ui))
	page_label.position = Vector2(origin.x + pager_width + _gap, pager_y)
	page_label.size = Vector2(_body_width - (pager_width + _gap) * 2.0, footer_height)
	var utility_y: = pager_y + footer_height + utility_gap
	var utility_width: = (_body_width - _gap) * 0.5
	back_button.position = Vector2(origin.x, utility_y)
	back_button.size = Vector2(utility_width, footer_height)
	report_button.position = Vector2(origin.x + utility_width + _gap, utility_y)
	report_button.size = Vector2(utility_width, footer_height)
	UiFonts.apply_to_label(hint, int(11 * _ui))
	hint.position = Vector2(origin.x, utility_y + footer_height + hint_gap)
	hint.size = Vector2(_body_width, hint_height)
	hint.visible = not tiny
	_show_page()

func _show_page() -> void:
	var cell_width: = (_body_width - _gap * (columns - 1)) / columns
	for index in entries.size():
		var button: = entries[index]
		var local_index: = index - page_index * page_size
		button.visible = local_index >= 0 and local_index < page_size
		button.disabled = not button.visible
		if not button.visible:
			continue
		@warning_ignore("integer_division")
		var row: int = local_index / columns
		UiFonts.apply_to_button(button, int(16 * _ui))
		button.position = _body_origin + Vector2((local_index % columns) * (cell_width + _gap), row * (_button_height + _gap))
		button.size = Vector2(cell_width, _button_height)
	prev_button.disabled = page_index == 0
	next_button.disabled = page_index == page_count - 1
	page_label.text = "%d / %d" % [page_index + 1, page_count]
	var focus: = get_viewport().gui_get_focus_owner()
	if focus is Button and focus in entries and not focus.visible:
		entries[page_index * page_size].grab_focus()

func set_page(index: int) -> void:
	page_index = clampi(index, 0, page_count - 1)
	_show_page()

func change_page(offset: int) -> void:
	set_page(page_index + offset)

func open_page() -> void:
	page_index = 0
	hint.text = DEFAULT_HINT
	hint.tooltip_text = ""
	show()
	_fit()
	if not entries.is_empty():
		entries[0].grab_focus()

func ensure_control_visible(control: Control) -> void:
	if not control is Button:
		return
	var index: = entries.find(control)
	if index >= 0:
		@warning_ignore("integer_division")
		set_page(index / page_size)

func show_status(message: String) -> void:
	hint.text = message.replace("\n", " ")
	hint.tooltip_text = message

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		if event.keycode == KEY_PAGEDOWN:
			change_page(1)
		elif event.keycode == KEY_PAGEUP:
			change_page(-1)
		elif event.keycode == KEY_ESCAPE:
			back_button.pressed.emit()
		else:
			return
		get_viewport().set_input_as_handled()
