extends CanvasLayer




signal reward_picked(reward_id: String)
signal next_stage_pressed

const MAX_HP_BONUS: = 120.0
const DEFENSE_BONUS: = 0.15
const MOVE_SPEED_BONUS: = 35.0
const COOLDOWN_SCALE: = 0.8

var _picked: bool = false
var _committed: = false
var _selected_id: = ""
var _subtitle: Label
var _idle_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _selected_style: StyleBoxFlat
var _panel_style: StyleBoxFlat
var _built: bool = false
var _buttons: Array[Button] = []
var next_button: Button
var _panel: PanelContainer
var _scroll: ScrollContainer
var _box: VBoxContainer

func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 125
	visible = false
	_build_ui()
	if not get_viewport().size_changed.is_connected(_fit_to_viewport):
		get_viewport().size_changed.connect(_fit_to_viewport)
	call_deferred("_fit_to_viewport")

func open_hub() -> void :
	_picked = false
	_committed = false
	_selected_id = ""
	visible = true
	for btn in _buttons:
		btn.disabled = false
		btn.modulate = Color.WHITE
	_refresh_reward_numbers()
	_refresh_selection()
	if next_button:
		next_button.disabled = true

func close_hub() -> void :
	visible = false

func _refresh_reward_numbers() -> void:
	var game := get_parent()
	var player: Node = game.player
	for button in _buttons:
		var id: String = button.get_meta("reward_id")
		var text := ""
		match id:
			"max_hp": text = CardNumbers.change("最大生命",player.max_player_health,player.max_player_health+MAX_HP_BONUS,"",false).text
			"defense": text = CardNumbers.change("减伤",player.damage_reduction*100,player.rest_defense_for(DEFENSE_BONUS)*100,"%",false).text
			"move_speed": text = CardNumbers.change("移速",player.effective_move_speed(),player.move_speed_for(player.SPEED+MOVE_SPEED_BONUS,player.growth_move_multiplier)).text
			"cooldown": text = CardNumbers.change("冲刺冷却",player.DASH_COOLDOWN*player.cooldown_scale,player.DASH_COOLDOWN*player.rest_cooldown_for(COOLDOWN_SCALE),"s").text + "\n枪支使用相同冷却倍率"
			_: text = str(game.equipment_panel.EQUIP_DEFS[id].title) + "\n" + str(preload("res://script/card_preview.gd").build(game,id).rows[0].text)
		button.set_meta("reward_label",text)

func _build_ui() -> void :
	if _built:
		return
	_built = true
	_idle_style = _button_style(GamePalette.UI_GREY_COOLDOWN, GamePalette.UI_GREY_BASE)
	_hover_style = _button_style(GamePalette.UI_GREY_COOLDOWN, GamePalette.UI_GREY_BORDER)
	_selected_style = _button_style(GamePalette.UI_GREY_BORDER, GamePalette.UI_GREY_ACTIVE)

	var dim: = ColorRect.new()
	dim.name = "Dim"
	dim.color = GamePalette.alpha(GamePalette.UI_GREY_COOLDOWN, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: = CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel: = PanelContainer.new()
	panel.name = "Panel"
	center.add_child(panel)
	_panel = panel
	_panel_style = _button_style(GamePalette.UI_GREY_COOLDOWN, GamePalette.UI_GREY_BASE)
	panel.add_theme_stylebox_override("panel", _panel_style)

	var scroll: = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	_scroll = scroll

	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_box = box

	var title: = Label.new()
	title.text = "休整  Rest"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_to_label(title, 28, true)
	box.add_child(title)

	var sub: = Label.new()
	_subtitle = sub
	sub.text = "预选一项奖励，可改选；进入下一关时领取"
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
	_add_reward_button(box, "monster_necklace", "怪物项链  击杀回血球")

	next_button = Button.new()
	next_button.name = "NextStage"
	next_button.text = "确认奖励并进入下一关"
	next_button.disabled = true
	next_button.custom_minimum_size = Vector2(460, 52)
	UiFonts.apply_to_button(next_button, 18)
	next_button.pressed.connect(_on_next_pressed)
	box.add_child(next_button)
	_fit_to_viewport()

func _fit_to_viewport() -> void :
	if _panel == null or _scroll == null or _box == null:
		return
	var vp: = get_viewport().get_visible_rect().size
	if vp.x < 8.0 or vp.y < 8.0:
		return
	var ui_scale: = clampf(vp.x / 450.0, 1, 2) if vp.y > vp.x else 1.0
	var margin: = 20.0 * ui_scale
	var padding: = 12.0 * ui_scale
	var stack_w: = minf(vp.x - margin * 2, 520.0 * ui_scale)
	var inner_w: = stack_w - padding * 2
	var button_h: = clampf(vp.y * 0.06, 40.0 * ui_scale, 56.0 * ui_scale)
	var title_size: = int(clampf(minf(vp.x, vp.y) * 0.055, 22.0 * ui_scale, 32.0 * ui_scale))
	_panel_style.content_margin_left = padding
	_panel_style.content_margin_right = padding
	_panel_style.content_margin_top = padding
	_panel_style.content_margin_bottom = padding
	_box.add_theme_constant_override("separation", int(10 * ui_scale))
	for style in [_idle_style, _hover_style, _selected_style]:
		style.set_border_width_all(int(2 * ui_scale))
	for child in _box.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(inner_w - 18 * ui_scale, button_h)
			UiFonts.apply_to_button(child, int((18 if child == next_button else 16) * ui_scale))
		elif child is Label:
			child.custom_minimum_size.x = inner_w - 18 * ui_scale
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var bold: = child == _box.get_child(0)
			UiFonts.apply_to_label(child, title_size if bold else int(15 * ui_scale), bold)
	var content_h: = 0.0
	for child in _box.get_children():
		content_h += child.get_combined_minimum_size().y
	content_h += float(maxi(_box.get_child_count() - 1, 0)) * 10.0 * ui_scale + padding * 2
	var stack_h: = minf(content_h, vp.y - margin * 2.0)
	_panel.custom_minimum_size = Vector2(stack_w, stack_h)
	_scroll.custom_minimum_size = Vector2(inner_w, maxf(40.0, stack_h - padding * 2))

func _add_reward_button(parent: Node, id: String, label_text: String) -> void :
	var btn: = Button.new()
	btn.text = label_text
	btn.set_meta("reward_id", id)
	btn.set_meta("reward_label", label_text)
	btn.custom_minimum_size = Vector2(460, 46)
	UiFonts.apply_to_button(btn, 16)
	btn.pressed.connect(_on_reward_pressed.bind(id))
	parent.add_child(btn)
	_buttons.append(btn)

func _on_reward_pressed(id: String) -> void :
	if _committed or not visible: return
	var valid: = false
	for button in _buttons:
		if str(button.get_meta("reward_id")) == id: valid = true
	if not valid: return
	_picked = true
	_selected_id = id
	_refresh_selection()
	if next_button:
		next_button.disabled = false

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style

func _refresh_selection() -> void :
	for button in _buttons:
		var chosen: = str(button.get_meta("reward_id")) == _selected_id
		button.text = ("已选  /  " if chosen else "") + str(button.get_meta("reward_label"))
		button.add_theme_stylebox_override("normal", _selected_style if chosen else _idle_style)
		button.add_theme_stylebox_override("hover", _selected_style if chosen else _hover_style)
		button.add_theme_stylebox_override("pressed", _selected_style)
		button.add_theme_stylebox_override("disabled", _selected_style if chosen else _idle_style)
		button.add_theme_color_override("font_color", GamePalette.UI_GREY_COOLDOWN if chosen else GamePalette.UI_GREY_BORDER)
		button.add_theme_color_override("font_hover_color", GamePalette.UI_GREY_COOLDOWN if chosen else Color.WHITE)
		button.add_theme_color_override("font_pressed_color", GamePalette.UI_GREY_COOLDOWN)
		button.add_theme_color_override("font_focus_color", GamePalette.UI_GREY_COOLDOWN if chosen else Color.WHITE)
	if _subtitle != null:
		_subtitle.text = "已预选，可继续改选；确认后领取" if _picked else "预选一项奖励，可改选；进入下一关时领取"

func _on_next_pressed() -> void :
	if not _picked or _committed or not visible: return
	_committed = true
	for button in _buttons: button.disabled = true
	next_button.disabled = true
	AudioManager.play_upgrade()
	reward_picked.emit(_selected_id)
	next_stage_pressed.emit()
