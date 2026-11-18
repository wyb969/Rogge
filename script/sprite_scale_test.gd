extends ColorRect

signal closed
const Art := preload("res://script/stage_monster_art.gd")
const Poses := preload("res://script/boss_pose.gd")
const Shell := preload("res://script/enemy_shell.gd")
const Guardian := preload("res://script/treasure_guardian.gd")
const Paint := preload("res://script/painted_ui.gd")
const Families := ["厨房", "文具", "快餐", "家电", "家具", "动物园", "恐龙", "蔬菜"]
const BossIds := ["lizard", "knight", "tide", "thunder", "wind-ranged", "wind-melee", "aegis", "guardian"]
const BossNames := ["冲锋巨蜥", "重装骑士", "潮汐巨象", "雷鬃狮王", "苍穹灵隼 · 远程", "苍穹灵隼 · 近战", "熔岩玄龟", "宝箱守卫"]

var field := Control.new()
var specimen := Sprite2D.new()
var title := Label.new()
var header := HBoxContainer.new()
var footer := VBoxContainer.new()
var monster_tab := Button.new()
var boss_tab := Button.new()
var play := Button.new()
var family := OptionButton.new()
var species := OptionButton.new()
var encounter := OptionButton.new()
var sliders: Array[HSlider] = []
var reading := Label.new()
var showing_boss := false
var _camera_zoom := Vector2.ONE
var _body_sizes := {}
var _body_scale := 1.0
var _facing := 1
var _boss_frames: SpriteFrames
var _phase := 0.0
var _pan := Vector2.ZERO
var _ui := 1.0
var _usable := false

func _ready() -> void:
	name = "SpriteScaleTest"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color("#152825")
	add_child(field)
	field.clip_contents = true
	var floor_art := TextureRect.new()
	floor_art.texture = Paint.MOSS_GROUND
	floor_art.texture_filter = TEXTURE_FILTER_NEAREST
	floor_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	floor_art.modulate = Color(0.67, 0.72, 0.69)
	floor_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(floor_art)
	floor_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	field.add_child(specimen)
	specimen.texture_filter = TEXTURE_FILTER_NEAREST
	field.gui_input.connect(_pan_input)

	title.text = L10n.text("怪物与 Boss 缩放测试")
	UiFonts.apply_to_label(title, 15, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	add_child(title)
	add_child(header)
	var back := Button.new()
	_button(header, back, L10n.text("返回"))
	back.pressed.connect(func(): closed.emit())
	var group := ButtonGroup.new()
	for tab in [monster_tab, boss_tab]:
		tab.toggle_mode = true
		tab.button_group = group
		_button(header, tab, L10n.text("小怪") if tab == monster_tab else "Boss")
		tab.pressed.connect(_switch.bind(tab == boss_tab))
	play.toggle_mode = true
	_button(header, play, L10n.text("暂停动作"))
	play.toggled.connect(func(stopped: bool): play.text = L10n.text("播放动作") if stopped else L10n.text("暂停动作"))
	add_child(footer)
	var selectors := HBoxContainer.new()
	footer.add_child(selectors)
	for selector in [family, species, encounter]:
		selector.fit_to_longest_item = false
		_button(selectors, selector, "")
		selector.get_popup().add_theme_font_override("font", UiFonts.ui())
		selector.item_selected.connect(func(_item: int): _select_specimen())
	for key in Families: family.add_item(L10n.text(key))
	for row in 10: species.add_item(L10n.text("种类 %02d") % (row + 1))
	for key in BossNames: encounter.add_item(L10n.text(key))
	var controls := HBoxContainer.new()
	footer.add_child(controls)
	UiFonts.apply_to_label(reading, 16, true)
	controls.add_child(reading)
	reading.custom_minimum_size.x = 57
	for i in 2:
		var slider := HSlider.new()
		slider.min_value = 0.5
		slider.max_value = 4.0
		slider.step = 0.05
		slider.value = 1.0
		slider.accessibility_name = (L10n.text("小怪") if i == 0 else "Boss") + " · " + L10n.text("实战倍率")
		slider.custom_minimum_size = Vector2(64, 44)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_child(slider)
		sliders.append(slider)
		slider.value_changed.connect(func(_value: float): _draw_pose())
	var reset := Button.new()
	_button(controls, reset, L10n.text("恢复 1×"))
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset.custom_minimum_size.x = 77
	reset.pressed.connect(reset_scale)
	resized.connect(_layout)
	get_viewport().size_changed.connect(_layout)

func _button(parent: Container, button: Button, caption: String) -> void:
	button.text = caption
	button.clip_text = true
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiFonts.apply_to_button(button, 15)
	Paint.style_button(button, true)
	parent.add_child(button)

func open(camera_zoom: Vector2, roster: Array[EnemyData]) -> void:
	_camera_zoom = camera_zoom
	for data in roster: _body_sizes[data.title] = data.body_scale
	_usable = true
	family.select(6) # Start with the dinosaur family.
	_switch(false)
	monster_tab.grab_focus()

func _switch(boss: bool) -> void:
	showing_boss = boss
	monster_tab.set_pressed_no_signal(not boss)
	boss_tab.set_pressed_no_signal(boss)
	family.visible = not boss
	species.visible = not boss
	encounter.visible = boss
	sliders[0].visible = not boss
	sliders[1].visible = boss
	_select_specimen()
	_layout()

func _select_specimen() -> void:
	_phase = 0.0
	_pan = Vector2.ZERO
	if showing_boss:
		var id: String = BossIds[encounter.selected]
		_boss_frames = load("res://rogge_art/bosses/%s/animations.tres" % id)
		var tile := _boss_frames.get_frame_texture(&"approach", 0) as AtlasTexture
		specimen.texture = tile.atlas
		specimen.hframes = 4
		specimen.vframes = 4
		_body_scale = Poses.ART_SCALE[id] * (Guardian.BODY_SCALE if id == "guardian" else 1.0)
		_facing = 1
	else:
		var index := family.selected
		var row := species.selected
		var slot: int = Art.SPECIES[index].find(row + 1)
		if slot >= 8: slot -= 8
		var role := str(Art.ROLE_SLOT.find_key(slot))
		_body_scale = Shell.WALK_ART_SCALE * float(_body_sizes.get(role, 1.0))
		_facing = Art.SOURCE_FACING[index][row]
		specimen.texture = Art.SHEETS[index]
		specimen.hframes = 20
		specimen.vframes = 10
	_draw_pose()

func _layout() -> void:
	if not _usable: return
	_ui = preload("res://script/boss_hud_layout.gd").display_scale(self)
	var logical_width := minf(730.0, size.x / _ui - 16.0)
	var inset := (size.x - logical_width * _ui) * 0.5
	title.position = Vector2(inset + 4 * _ui, 0)
	title.scale = Vector2.ONE * _ui
	title.size = Vector2(logical_width * 0.5 - 28, 48)
	header.scale = Vector2.ONE * _ui
	footer.scale = header.scale
	header.size = Vector2(logical_width, 44)
	footer.size = Vector2(logical_width, footer.get_combined_minimum_size().y)
	# The global fullscreen control occupies the top edge.
	header.position = Vector2(inset, 52 * _ui)
	footer.position = Vector2(inset, size.y - (footer.size.y + 7) * _ui)
	field.position = Vector2(0, header.position.y + header.size.y * _ui + 4 * _ui)
	field.size = Vector2(size.x, maxf(1, footer.position.y - field.position.y - 4 * _ui))
	_draw_pose()

func reset_scale() -> void:
	_pan = Vector2.ZERO
	sliders[int(showing_boss)].value = 1.0
	_draw_pose()

func _process(delta: float) -> void:
	if _usable and not play.button_pressed:
		var previous_frame := floori(_phase)
		_phase = fmod(_phase + delta * 6.0, 120.0)
		if floori(_phase) != previous_frame: _draw_pose()

func _draw_pose() -> void:
	if not _usable: return
	var factor := sliders[int(showing_boss)].value
	var caption := "%.2f×" % factor
	if reading.text != caption: reading.text = caption
	specimen.scale = _camera_zoom * (_body_scale * factor)
	var frame_index := floori(_phase)
	if showing_boss:
		var count := _boss_frames.get_frame_count(&"approach")
		var tile := _boss_frames.get_frame_texture(&"approach", frame_index % count) as AtlasTexture
		specimen.frame_coords = Vector2i(tile.region.position / tile.region.size)
	else:
		specimen.frame_coords = Vector2i(4 + frame_index % 4, species.selected)
	specimen.flip_h = _facing < 0
	var limit := (specimen.get_rect().size * specimen.scale * 0.5).max(Vector2.ZERO)
	_pan = _pan.clamp(-limit, limit)
	specimen.position = (field.size * 0.5).round() + _pan

func _pan_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_pan += event.relative
		_draw_pose()
		field.accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()
