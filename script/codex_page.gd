extends CanvasLayer
signal closed
var game: Node
var selected_id := ""
var entries: Array[Dictionary] = []
var category := 0
var _detail_open := false
var _narrow := false
var _root: PanelContainer
var _header: Label
var _back: Button
var _list_back: Button
var _picker: OptionButton
var _search: LineEdit
var _body: HBoxContainer
var _list_scroll: ScrollContainer
var _list: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
var _icon: TextureRect
var _title: Label
var _text: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 220
	visible = false
	entries = CodexData.entries()
	_root = PanelContainer.new()
	_root.add_theme_stylebox_override("panel",GamePalette.neutral_surface(GamePalette.UI_SLOT,GamePalette.UI_GREY_BORDER))
	add_child(_root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	_root.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	_header = Label.new()
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_header)
	_list_back = _button("词典列表",show_list)
	header.add_child(_list_back)
	_back = _button("返回",close_page)
	header.add_child(_back)
	var filters := HBoxContainer.new()
	box.add_child(filters)
	_picker = OptionButton.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.item_selected.connect(func(index: int): category=index;_detail_open=false;_populate();_show_entry();_fit())
	filters.add_child(_picker)
	_search = LineEdit.new()
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_value: String):_populate())
	filters.add_child(_search)
	_body = HBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_body)
	_list_scroll = ScrollContainer.new()
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(_list_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.add_child(_list)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation",12)
	_detail_scroll.add_child(_detail)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail.add_child(_icon)
	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_child(_title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_child(_text)
	get_viewport().size_changed.connect(_fit)
	SettingsStore.language_changed.connect(func(_value: String):_localize())
	_localize()

func _button(key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = L10n.text(key)
	button.pressed.connect(action)
	GamePalette.apply_neutral_button(button)
	return button

func _localize() -> void:
	if _picker == null: return
	_header.text = L10n.text("游戏词典")
	_back.text = L10n.text("返回")
	_list_back.text = L10n.text("词典列表")
	_search.placeholder_text = L10n.text("搜索名称")
	_picker.clear()
	for key in CodexData.CATEGORIES: _picker.add_item(L10n.text(key))
	_picker.select(category)
	_populate()
	_show_entry()
	_fit()

func open_page(host: Node = null, id: String = "") -> void:
	game = host
	visible = true
	if not id.is_empty():
		selected_id = id
		for entry in entries:
			if entry.id==id: category=entry.category
		_detail_open = true
	else:
		_detail_open = false
	_localize()
	_back.grab_focus()

func close_page() -> void:
	visible = false
	game = null
	closed.emit()

func show_list() -> void:
	_detail_open = false
	_fit()
	_picker.grab_focus()

func go_back() -> void:
	if _narrow and _detail_open: show_list()
	else: close_page()

func _populate() -> void:
	for child in _list.get_children(): _list.remove_child(child);child.queue_free()
	var count := 0
	for entry in entries:
		if entry.category!=category: continue
		var title := L10n.text(entry.title)
		if not _search.text.is_empty() and not title.to_lower().contains(_search.text.to_lower()): continue
		var button := _button(entry.title,_select.bind(str(entry.id)))
		button.icon = CodexData.texture_for(entry)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = title
		button.set_meta("entry_id",entry.id)
		_list.add_child(button)
		count+=1
	if count==0:
		var empty := Label.new()
		empty.text = L10n.text("没有匹配的条目")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_list.add_child(empty)
	_fit()

func _select(id: String) -> void:
	selected_id = id
	_detail_open = true
	_detail_scroll.scroll_vertical = 0
	_show_entry()
	_fit()
	if _narrow: _list_back.grab_focus()

func _show_entry() -> void:
	var found := {}
	for entry in entries:
		if entry.id == selected_id and entry.category==category: found=entry;break
	if found.is_empty():
		for entry in entries:
			if entry.category==category: found=entry;selected_id=entry.id;break
	if found.is_empty(): return
	_icon.texture = CodexData.texture_for(found)
	_title.text = L10n.text(found.title)
	_text.text = CodexData.description(found,game if is_instance_valid(game) else null)

func _ui_scale() -> float:
	var transform := get_viewport().get_final_transform()
	var ratio := 1.0
	if OS.has_feature("web"):
		var css: Variant = JavaScriptBridge.eval("document.getElementById('canvas').getBoundingClientRect().width",true)
		if (css is float or css is int) and float(css)>0: ratio=float(get_tree().root.size.x)/float(css)
	return ratio/maxf((transform*Vector2.RIGHT-transform*Vector2.ZERO).length(),0.1)

func _fit() -> void:
	if _text==null: return
	var vp := get_viewport().get_visible_rect().size
	var ui := _ui_scale()
	_narrow = vp.x/ui<720
	_root.offset_left = 12*ui
	_root.offset_top = 12*ui
	_root.offset_right = vp.x-12*ui
	_root.offset_bottom = vp.y-12*ui
	_list_back.visible = _narrow and _detail_open
	_list_scroll.visible = not _narrow or not _detail_open
	_detail_scroll.visible = not _narrow or _detail_open
	_list_scroll.custom_minimum_size.x = 0 if _narrow else minf(300*ui,vp.x*0.35)
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL if _narrow else Control.SIZE_FILL
	_header.text = "" if _narrow and _detail_open else L10n.text("游戏词典")
	_back.custom_minimum_size.x = 86*ui
	_list_back.custom_minimum_size.x = 114*ui
	UiFonts.apply_to_label(_header,int(20*ui),true)
	for button in [_back,_list_back,_picker]:
		UiFonts.apply_to_button(button,int(13*ui))
		button.custom_minimum_size.y = 44*ui
	UiFonts.apply_to_label(_search,int(14*ui))
	_icon.custom_minimum_size = Vector2.ONE*96*ui
	UiFonts.apply_to_label(_title,int(20*ui),true)
	UiFonts.apply_to_label(_text,int(14*ui))
	for button in _list.get_children():
		if button is Button:
			UiFonts.apply_to_button(button,int(14*ui))
			button.custom_minimum_size.y=56*ui
			button.add_theme_constant_override("icon_max_width",40*ui)
