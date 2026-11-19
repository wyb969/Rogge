extends CanvasLayer
var host: Node
var active := false
var origin := "run"
var previous_pause := false
var controls_visible := false
var saved_focus: WeakRef
var codex: Node
var panel: PanelContainer
var shield: ColorRect
var box: VBoxContainer
var title: Label
var resume_button: Button
var settings_button: Button
var codex_button: Button
var home_button: Button
var _settings_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 210
	host = get_parent()
	shield = ColorRect.new()
	shield.color = Color(0.02,0.035,0.055,0.94)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shield)
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel = PanelContainer.new()
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_theme_stylebox_override("panel",preload("res://script/painted_ui.gd").TIDE)
	add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	panel.add_child(box)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	resume_button = _button("继续游戏",close_menu)
	settings_button = _button("Settings",open_settings)
	codex_button = _button("游戏词典",func():open_codex())
	home_button = _button("返回主页",_home)
	codex = preload("res://script/codex_page.gd").new()
	codex.name = "CodexPage"
	add_child(codex)
	codex.closed.connect(_codex_closed)
	get_viewport().size_changed.connect(_fit)
	SettingsStore.language_changed.connect(_language_changed)
	visible = false
	_fit()

func _button(key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = L10n.text(key)
	button.pressed.connect(action)
	GamePalette.apply_neutral_button(button)
	box.add_child(button)
	return button

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or event.keycode!=KEY_ESCAPE or not event.pressed or event.echo: return
	if active:
		get_viewport().set_input_as_handled()
		if _settings_open: host.settings_page.close_page()
		elif codex.visible: codex.go_back()
		else: close_menu()
	elif _can_open():
		get_viewport().set_input_as_handled()
		open_menu()

func _can_open() -> bool:
	if is_instance_valid(host.game) and is_instance_valid(host.game.forge_screen) and host.game.forge_screen.working: return false
	return is_instance_valid(host.game) and host.game.visible and host.game.player.player_health>0 and not host._starting_run and not host._returning_home and not host.game._death_presented

func _begin(from: String) -> void:
	if active: return
	origin=from
	previous_pause=get_tree().paused
	controls_visible=host.mobile_controls.visible
	var focus := get_viewport().gui_get_focus_owner()
	saved_focus=weakref(focus) if focus!=null else null
	if focus!=null: focus.release_focus()
	active=true
	visible=true
	get_tree().paused=true
	host.mobile_controls.hide_controls()

func open_menu() -> void:
	if not active and not _can_open(): return
	_begin("run")
	panel.show()
	_fit()
	resume_button.grab_focus()

func open_codex(id: String = "", from: String = "run") -> void:
	_begin(from)
	panel.hide()
	var game: Node = host.game if origin!="home" else null
	codex.open_page(game,id)

func _codex_closed() -> void:
	if origin in ["home","card"]: close_menu()
	else:
		panel.show()
		codex_button.grab_focus()

func open_settings() -> void:
	if not active: return
	panel.hide()
	host._ensure_settings_page()
	host.settings_page.layer=230
	_settings_open=true
	if not host.settings_page.closed.is_connected(_settings_closed):host.settings_page.closed.connect(_settings_closed)
	host.settings_page.open_page()
	host.settings_page.hint_label.text=L10n.text("从主页设置中拖动按键位置。")
	# Controls remain disabled while inspecting an active run; all saved layout values stay intact.
	host.settings_page.back_button.grab_focus()

func _settings_closed() -> void:
	if not _settings_open:return
	_settings_open=false
	host.settings_page.layer=70
	host.settings_page.hint_label.text=L10n.text("拖动摇杆和冲刺键   Drag stick and DASH")
	panel.show()
	settings_button.grab_focus()

func close_menu() -> void:
	if not active:return
	var restore_pause:=previous_pause
	active=false
	visible=false
	codex.hide()
	if _settings_open:
		_settings_open=false
		host.settings_page.hide()
		host.settings_page.layer=70
	get_tree().paused=restore_pause
	MobileInput.clear_move()
	MobileInput.clear_dash()
	if controls_visible:host.mobile_controls.show_controls()
	if saved_focus!=null:
		var focus: Object=saved_focus.get_ref()
		if is_instance_valid(focus) and focus is Control and focus.is_visible_in_tree():focus.grab_focus()

func dismiss() -> void:
	# Run teardown owns the following pause state; never resume an old scene here.
	active=false
	visible=false
	codex.hide()
	if _settings_open:
		_settings_open=false
		host.settings_page.hide()
		host.settings_page.layer=70

func _home() -> void:
	dismiss()
	host._on_game_end_ui_main_menu_pressed()

func _language_changed(_language: String) -> void:
	title.text=L10n.text("游戏已暂停")
	resume_button.text=L10n.text("继续游戏")
	codex_button.text=L10n.text("游戏词典")
	home_button.text=L10n.text("返回主页")
	if is_instance_valid(host.game): host.game.refresh_language()
	host.fullscreen_toggle._refresh_label()
	_fit()

func _fit() -> void:
	var vp:=get_viewport().get_visible_rect().size
	var ui: float=codex._ui_scale() if codex!=null else 1.0
	var width:=minf(360*ui,vp.x-32*ui)
	title.text=L10n.text("游戏已暂停")
	UiFonts.apply_to_label(title,int(22*ui),true)
	for button in [resume_button,settings_button,codex_button,home_button]:
		UiFonts.apply_to_button(button,int(16*ui))
		button.custom_minimum_size=Vector2(width,44*ui)
	panel.size=Vector2(width,0)
	panel.position=(vp-panel.get_combined_minimum_size())*0.5
