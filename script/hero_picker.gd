extends CenterContainer

signal chosen(index: int)
signal cancelled
const HEROES := preload("res://script/hero_roster.gd")
const EQUIPMENT := preload("res://script/equipment_panel.gd")
var grid := GridContainer.new()
var cards: Array[Button] = []
var portraits: Array[TextureRect] = []
var names: Array[Label] = []
var perks: Array[Label] = []
var back := Button.new()
var title := Label.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply_to_label(title, 25, true)
	box.add_child(title)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for index in HEROES.TITLES.size():
		var card := Button.new()
		cards.append(card)
		grid.add_child(card)
		var content := VBoxContainer.new()
		card.add_child(content)
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		var portrait := TextureRect.new()
		portraits.append(portrait)
		content.add_child(portrait)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.texture = HEROES.FRAMES[index].get_frame_texture(&"idle_right", 0)
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		for collection in [names, perks]:
			var label := Label.new()
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(label)
			collection.append(label)
		card.pressed.connect(func(): chosen.emit(index))
	UiFonts.apply_to_button(back, 16)
	back.custom_minimum_size.y = 40
	box.add_child(back)
	back.pressed.connect(func(): cancelled.emit())
	resized.connect(_layout)

func open(selected: int) -> void:
	show()
	title.text = L10n.text("选择角色")
	back.text = L10n.text("返回")
	for i in cards.size():
		var perk: String = EQUIPMENT.EQUIP_DEFS[HEROES.START_CARDS[i]].title
		names[i].text = L10n.text(HEROES.TITLES[i])
		perks[i].text = L10n.text("初始能力：%s") % L10n.text(perk)
		cards[i].accessibility_name = names[i].text + ", " + perks[i].text
	_layout()
	cards[selected].grab_focus()

func _layout() -> void:
	if not is_inside_tree() or cards.size() != HEROES.TITLES.size(): return
	var ui := maxf(0.1, preload("res://script/boss_hud_layout.gd").display_scale(self))
	var available := size / ui
	grid.columns = 4 if available.x >= 680 else 2
	var width := minf(196, (available.x - 28 - 8 * (grid.columns-1)) / grid.columns)
	var height := clampf((available.y - 104) / (2 if grid.columns == 2 else 1), 78, 170)
	var gap := roundi(6 * ui)
	grid.add_theme_constant_override("h_separation", gap)
	grid.add_theme_constant_override("v_separation", gap)
	UiFonts.apply_to_label(title, roundi(23 * ui), true)
	UiFonts.apply_to_button(back, roundi(16 * ui))
	back.custom_minimum_size.y = 40 * ui
	for i in cards.size():
		cards[i].custom_minimum_size = Vector2(width, height) * ui
		portraits[i].custom_minimum_size.y = clampf(height - 70, 20, 76) * ui
		UiFonts.apply_to_label(names[i], roundi(15 * ui), true)
		UiFonts.apply_to_label(perks[i], roundi(13 * ui))
		perks[i].modulate = Color(0.80, 0.89, 0.82)

func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()
