extends CanvasLayer
## Rest hub after the stage 1 boss. One run-long reward, then Next Stage.
## Cooldown reward scales dash cooldown and the gun's fire interval / shot lock.
## It does not change the axe, orbiting books, drones, molotov, or freeze.

signal reward_picked(reward_id: String)
signal next_stage_pressed

const MAX_HP_BONUS := 120.0
const DEFENSE_BONUS := 0.15
const MOVE_SPEED_BONUS := 35.0
const COOLDOWN_SCALE := 0.8

var _picked: bool = false
var _built: bool = false
var _buttons: Array[Button] = []
var next_button: Button
var _panel: PanelContainer
var _scroll: ScrollContainer
var _box: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125
	visible = false
	_build_ui()
	if not get_viewport().size_changed.is_connected(_fit_to_viewport):
		get_viewport().size_changed.connect(_fit_to_viewport)
	call_deferred("_fit_to_viewport")

func open_hub() -> void:
	_picked = false
	visible = true
	for btn in _buttons:
		btn.disabled = false
		btn.modulate = Color.WHITE
	if next_button:
		next_button.disabled = true

func close_hub() -> void:
	visible = false

func _build_ui() -> void:
	if _built:
		return
	_built = true

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.03, 0.05, 0.1, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	center.add_child(panel)
	_panel = panel

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	_scroll = scroll

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_box = box

	var title := Label.new()
	title.text = "休整  Rest"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_to_label(title, 28, true)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "选择一项奖励   Choose one"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_to_label(sub, 16)
	box.add_child(sub)

	_add_reward_button(box, "max_hp", "生命 +120")
	_add_reward_button(box, "defense", "减伤 15%")
	_add_reward_button(box, "move_speed", "移速 +35")
	_add_reward_button(box, "cooldown", "冷却 -20%  Dash+Gun")
	_add_reward_button(box, "regen_up", "回复  Regen")
	_add_reward_button(box, "lifesteal_up", "吸血  Lifesteal")
	_add_reward_button(box, "shield_up", "玉佩  Shield")

	next_button = Button.new()
	next_button.name = "NextStage"
	next_button.text = "下一关  Next Stage"
	next_button.disabled = true
	next_button.custom_minimum_size = Vector2(460, 52)
	UiFonts.apply_to_button(next_button, 18)
	next_button.pressed.connect(_on_next_pressed)
	box.add_child(next_button)
	_fit_to_viewport()

func _fit_to_viewport() -> void:
	if _panel == null or _scroll == null or _box == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 8.0 or vp.y < 8.0:
		return
	var margin := 20.0
	var stack_w := clampf(vp.x - margin * 2.0, 220.0, 520.0)
	var button_h := clampf(vp.y * 0.06, 40.0, 56.0)
	var title_size := int(clampf(minf(vp.x, vp.y) * 0.055, 22.0, 32.0))
	for child in _box.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(stack_w - 28.0, button_h)
		elif child is Label:
			child.custom_minimum_size.x = stack_w - 28.0
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var bold := child == _box.get_child(0)
			UiFonts.apply_to_label(child, title_size if bold else 15, bold)
	var content_h := 0.0
	for child in _box.get_children():
		content_h += child.get_combined_minimum_size().y
	content_h += float(maxi(_box.get_child_count() - 1, 0)) * 10.0 + 24.0
	var stack_h := minf(content_h, vp.y - margin * 2.0)
	_panel.custom_minimum_size = Vector2(stack_w, stack_h)
	_scroll.custom_minimum_size = Vector2(stack_w - 16.0, maxf(40.0, stack_h - 16.0))

func _add_reward_button(parent: Node, id: String, label_text: String) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.set_meta("reward_id", id)
	btn.custom_minimum_size = Vector2(460, 46)
	UiFonts.apply_to_button(btn, 16)
	btn.pressed.connect(_on_reward_pressed.bind(id))
	parent.add_child(btn)
	_buttons.append(btn)

func _on_reward_pressed(id: String) -> void:
	if _picked:
		return
	_picked = true
	for btn in _buttons:
		btn.disabled = true
		if str(btn.get_meta("reward_id", "")) == id:
			btn.modulate = Color(0.7, 1.0, 0.72)
	if next_button:
		next_button.disabled = false
	reward_picked.emit(id)

func _on_next_pressed() -> void:
	if not _picked:
		return
	next_stage_pressed.emit()
